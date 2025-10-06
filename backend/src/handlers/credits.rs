use crate::auth;
use crate::credits as credits_mod;
use crate::db;
use crate::error::AppError;
use crate::models::{BalanceResponse, RevenueCatValidateRequest, RevenueCatValidateResponse};
use crate::pricing;
use worker::{Request, Response, RouteContext};

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

async fn validate_revenuecat_purchase_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;

    let body: RevenueCatValidateRequest = req.json().await.map_err(|_| {
        AppError::BadRequest("Invalid request body".into())
    })?;

    if body.product_id != "sora_starter_pack" {
        return Err(AppError::BadRequest("Invalid product ID".into()));
    }

    let new_balance = credits_mod::add_credits(
        &ctx.env,
        &user_id,
        pricing::STARTER_PACK_CREDITS,
        &format!("Purchased Starter Pack ({})", body.transaction_id),
        Some(&body.transaction_id),
    )
    .await?;

    let response = RevenueCatValidateResponse {
        success: true,
        credits_added: pricing::STARTER_PACK_CREDITS,
        new_balance,
    };

    Response::from_json(&response).map_err(|e| e.into())
}

pub async fn validate_revenuecat_purchase(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    validate_revenuecat_purchase_inner(req, ctx).await.or_else(|e| e.to_response())
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
