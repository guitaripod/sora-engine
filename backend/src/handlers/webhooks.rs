use crate::credits;
use crate::db;
use crate::error::AppError;
use crate::models::OpenAIWebhookEvent;
use crate::openai_client;
use worker::{console_log, Request, Response, RouteContext};

async fn openai_webhook_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    let body_text = req.text().await.map_err(|_| {
        AppError::BadRequest("Failed to read request body".into())
    })?;

    let event: OpenAIWebhookEvent = serde_json::from_str(&body_text).map_err(|e| {
        AppError::BadRequest(format!("Invalid webhook payload: {}", e))
    })?;

    console_log!("Received OpenAI webhook: type={}, video_id={}", event.event_type, event.data.id);

    match event.event_type.as_str() {
        "video.completed" => handle_video_completed(&ctx, &event.data.id).await?,
        "video.failed" => handle_video_failed(&ctx, &event.data.id).await?,
        _ => {
            console_log!("Unknown webhook event type: {}", event.event_type);
        }
    }

    Response::ok("OK").map_err(|e| e.into())
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
