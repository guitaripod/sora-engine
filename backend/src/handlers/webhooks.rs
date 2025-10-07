use crate::credits;
use crate::db;
use crate::error::AppError;
use crate::models::OpenAIWebhookEvent;
use crate::openai_client;
use uuid::Uuid;
use worker::{console_log, Request, Response, RouteContext};

async fn openai_webhook_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    verify_webhook_auth(&req, &ctx.env)?;

    let body_text = req.text().await.map_err(|_| {
        AppError::BadRequest("Failed to read request body".into())
    })?;

    let event: OpenAIWebhookEvent = serde_json::from_str(&body_text).map_err(|e| {
        AppError::BadRequest(format!("Invalid webhook payload: {}", e))
    })?;

    if is_duplicate_webhook(&ctx.env, &event).await? {
        console_log!("Duplicate webhook ignored: type={}, video_id={}", event.event_type, event.data.id);
        return Response::ok("OK").map_err(|e| e.into());
    }

    store_webhook_event(&ctx.env, &event).await?;

    console_log!("Received OpenAI webhook: type={}, video_id={}", event.event_type, event.data.id);

    match event.event_type.as_str() {
        "video.completed" => handle_video_completed(&ctx, &event.data.id).await?,
        "video.failed" => handle_video_failed(&ctx, &event.data.id).await?,
        _ => {
            console_log!("Unknown webhook event type: {}", event.event_type);
        }
    }

    mark_webhook_processed(&ctx.env, &event.data.id, &event.event_type).await?;

    Response::ok("OK").map_err(|e| e.into())
}

fn verify_webhook_auth(req: &Request, env: &worker::Env) -> Result<(), AppError> {
    let webhook_secret = env.var("WEBHOOK_SECRET")
        .map_err(|_| AppError::InternalError("WEBHOOK_SECRET not configured".into()))?
        .to_string();

    let auth_header = req.headers().get("Authorization")
        .ok().flatten()
        .ok_or_else(|| AppError::Unauthorized("Missing webhook authentication".into()))?;

    if !auth_header.starts_with("Bearer ") {
        return Err(AppError::Unauthorized("Invalid webhook auth format".into()));
    }

    let token = auth_header.trim_start_matches("Bearer ");

    if token != webhook_secret {
        return Err(AppError::Unauthorized("Invalid webhook secret".into()));
    }

    Ok(())
}

async fn is_duplicate_webhook(env: &worker::Env, event: &OpenAIWebhookEvent) -> Result<bool, AppError> {
    let database = env.d1("DB").map_err(|_| AppError::InternalError("Failed to get DB".into()))?;

    let result = database
        .prepare("SELECT id FROM webhook_events WHERE openai_video_id = ? AND event_type = ? LIMIT 1")
        .bind(&[event.data.id.clone().into(), event.event_type.clone().into()])?
        .first::<String>(None)
        .await;

    match result {
        Ok(Some(_)) => Ok(true),
        Ok(None) => Ok(false),
        Err(_) => Ok(false),
    }
}

async fn store_webhook_event(env: &worker::Env, event: &OpenAIWebhookEvent) -> Result<(), AppError> {
    let database = env.d1("DB").map_err(|_| AppError::InternalError("Failed to get DB".into()))?;

    let event_id = Uuid::new_v4().to_string();
    let payload = serde_json::to_string(event)
        .map_err(|_| AppError::InternalError("Failed to serialize webhook event".into()))?;

    database
        .prepare("INSERT INTO webhook_events (id, event_type, openai_video_id, payload, created_at) VALUES (?, ?, ?, ?, datetime('now'))")
        .bind(&[event_id.into(), event.event_type.clone().into(), event.data.id.clone().into(), payload.into()])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(format!("Failed to store webhook event: {:?}", e)))?;

    Ok(())
}

async fn mark_webhook_processed(env: &worker::Env, openai_video_id: &str, event_type: &str) -> Result<(), AppError> {
    let database = env.d1("DB").map_err(|_| AppError::InternalError("Failed to get DB".into()))?;

    database
        .prepare("UPDATE webhook_events SET processed = 1, processed_at = datetime('now') WHERE openai_video_id = ? AND event_type = ?")
        .bind(&[openai_video_id.into(), event_type.into()])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(format!("Failed to mark webhook processed: {:?}", e)))?;

    Ok(())
}

pub async fn openai_webhook(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    openai_webhook_inner(req, ctx).await.or_else(|e| e.to_response())
}

async fn handle_video_completed(ctx: &RouteContext<()>, openai_video_id: &str) -> Result<(), AppError> {
    let _video_status = openai_client::get_video_status(&ctx.env, openai_video_id).await?;

    let video = db::get_video_by_openai_id(&ctx.env, openai_video_id).await?;

    let service_url = ctx.env
        .var("SERVICE_URL")
        .map_err(|_| AppError::InternalError("SERVICE_URL not configured".into()))?
        .to_string();

    let video_url = format!("{}/v1/videos/{}/proxy?variant=video&user_id={}", service_url, openai_video_id, video.user_id);
    let thumbnail_url = format!("{}/v1/videos/{}/proxy?variant=thumbnail&user_id={}", service_url, openai_video_id, video.user_id);
    let spritesheet_url = format!("{}/v1/videos/{}/proxy?variant=spritesheet&user_id={}", service_url, openai_video_id, video.user_id);

    db::update_video_completed(
        &ctx.env,
        openai_video_id,
        &video_url,
        &thumbnail_url,
        &spritesheet_url,
    )
    .await?;

    console_log!("Video completed: {}", openai_video_id);

    Ok(())
}

async fn handle_video_failed(ctx: &RouteContext<()>, openai_video_id: &str) -> Result<(), AppError> {
    let video = db::get_video_by_openai_id(&ctx.env, openai_video_id).await?;

    let error_message = "Video generation failed on OpenAI side".to_string();

    db::update_video_failed(&ctx.env, openai_video_id, &error_message).await?;

    credits::refund_credits(
        &ctx.env,
        &video.user_id,
        &video.id,
        video.credits_cost,
    )
    .await?;

    console_log!("Video failed and credits refunded: {}", openai_video_id);

    Ok(())
}
