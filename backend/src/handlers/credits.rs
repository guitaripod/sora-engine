use crate::auth;
use crate::credits as credits_mod;
use crate::db;
use crate::error::AppError;
use crate::models::{BalanceResponse, AppleIAPValidateRequest, AppleIAPValidateResponse};
use crate::pricing;
use worker::{Request, Response, RouteContext};
use serde::Deserialize;

async fn get_balance_inner(req: Request, ctx: RouteContext<()>) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;
    let user = db::get_user_by_id(&ctx.env, &user_id).await?;

    let response = BalanceResponse {
        credits_balance: user.credits_balance,
        usd_equivalent: pricing::credits_to_usd(user.credits_balance),
    };

    Response::from_json(&response).map_err(|e| e.into())
}

pub async fn get_balance(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    get_balance_inner(req, ctx).await.or_else(|e| e.to_response())
}

async fn get_transactions_inner(
    req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;

    let transactions = db::get_user_transactions(&ctx.env, &user_id, 50).await?;

    Response::from_json(&transactions).map_err(|e| e.into())
}

pub async fn get_transactions(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    get_transactions_inner(req, ctx).await.or_else(|e| e.to_response())
}

#[derive(Debug, Deserialize)]
struct AppleTransactionPayload {
    #[serde(rename = "transactionId")]
    transaction_id: String,
    #[serde(rename = "productId")]
    product_id: String,
    #[serde(rename = "bundleId")]
    bundle_id: String,
    #[serde(rename = "purchaseDate")]
    #[allow(dead_code)]
    purchase_date: i64,
}

async fn validate_apple_iap_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;

    let body: AppleIAPValidateRequest = req.json().await.map_err(|_| {
        AppError::BadRequest("Invalid request body".into())
    })?;

    let parts: Vec<&str> = body.transaction_jws.split('.').collect();
    if parts.len() != 3 {
        return Err(AppError::BadRequest("Invalid JWS format".into()));
    }

    let payload_base64 = parts[1];
    use base64::{Engine as _, engine::general_purpose};
    let payload_bytes = general_purpose::URL_SAFE_NO_PAD.decode(payload_base64)
        .map_err(|_| AppError::BadRequest("Invalid JWS encoding".into()))?;

    let transaction: AppleTransactionPayload = serde_json::from_slice(&payload_bytes)
        .map_err(|_| AppError::BadRequest("Invalid transaction data".into()))?;

    let expected_bundle_id = ctx.env.var("APPLE_CLIENT_ID")
        .map(|v| v.to_string())
        .unwrap_or_else(|_| "com.guitaripod.sora".to_string());

    if transaction.bundle_id != expected_bundle_id {
        return Err(AppError::BadRequest("Invalid bundle ID".into()));
    }

    if transaction.product_id != "sora_starter_pack" {
        return Err(AppError::BadRequest("Invalid product ID".into()));
    }

    let db = ctx.env.d1("DB")
        .map_err(|e| AppError::InternalError(format!("Failed to get DB: {}", e)))?;

    let existing = db
        .prepare("SELECT id FROM credit_transactions WHERE revenuecat_transaction_id = ? LIMIT 1")
        .bind(&[transaction.transaction_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    if existing.is_some() {
        return Err(AppError::BadRequest("Transaction already processed".into()));
    }

    let new_balance = credits_mod::add_credits(
        &ctx.env,
        &user_id,
        pricing::STARTER_PACK_CREDITS,
        "Purchased Starter Pack",
        Some(&transaction.transaction_id),
    )
    .await?;

    let response = AppleIAPValidateResponse {
        success: true,
        credits_added: pricing::STARTER_PACK_CREDITS,
        new_balance,
        transaction_id: transaction.transaction_id,
    };

    Response::from_json(&response).map_err(|e| e.into())
}

pub async fn validate_apple_iap(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    validate_apple_iap_inner(req, ctx).await.or_else(|e| e.to_response())
}

pub async fn get_credit_packs(_req: Request, _ctx: RouteContext<()>) -> worker::Result<Response> {
    let packs = serde_json::json!([
        {
            "id": "sora_starter_pack",
            "name": "Starter Pack",
            "credits": pricing::STARTER_PACK_CREDITS,
            "price_usd": pricing::STARTER_PACK_PRICE_USD,
            "popular": true,
            "estimated_videos": {
                "sora_2_5s": 10,
                "sora_2_8s": 6,
                "sora_2_pro_5s": 3,
                "sora_2_pro_8s": 2
            }
        }
    ]);

    Response::from_json(&packs)
}
