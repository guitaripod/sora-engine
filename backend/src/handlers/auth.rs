use crate::auth;
use crate::db;
use crate::error::AppError;
use crate::models::{AppleTokenRequest, AuthResponse};
use worker::{Request, Response, RouteContext};

async fn apple_sign_in_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    let body: AppleTokenRequest = req.json().await.map_err(|_| {
        AppError::BadRequest("Invalid request body".into())
    })?;

    let (apple_user_id, email) = auth::verify_apple_token(&body.identity_token, &ctx.env).await?;

    let (user, is_new) = db::get_or_create_user(&ctx.env, &apple_user_id, email).await?;

    let response = AuthResponse {
        user_id: user.id,
        credits_balance: user.credits_balance,
        created: is_new,
    };

    let json_string = serde_json::to_string(&response).map_err(|e| {
        AppError::InternalError(format!("JSON serialization failed: {}", e))
    })?;

    let mut response = Response::ok(json_string).map_err(|e| {
        AppError::InternalError(format!("Response creation failed: {}", e))
    })?;

    response.headers_mut().set("Content-Type", "application/json")?;

    Ok(response)
}

pub async fn apple_sign_in(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    apple_sign_in_inner(req, ctx).await.or_else(|e| e.to_response())
}

async fn get_me_inner(req: Request, ctx: RouteContext<()>) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;
    let user = db::get_user_by_id(&ctx.env, &user_id).await?;

    let response = serde_json::json!({
        "id": user.id,
        "email": user.email,
        "credits_balance": user.credits_balance,
        "total_videos_generated": user.total_videos_generated,
        "created_at": user.created_at.to_rfc3339(),
    });

    Response::from_json(&response).map_err(|e| e.into())
}

pub async fn get_me(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    get_me_inner(req, ctx).await.or_else(|e| e.to_response())
}
