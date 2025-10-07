use crate::auth;
use crate::credits;
use crate::db;
use crate::error::AppError;
use crate::models::{CreateVideoRequest, CreateVideoResponse, EstimateRequest, EstimateResponse, VideoListResponse, Video};
use crate::openai_client;
use crate::pricing;
use crate::rate_limit;
use worker::{console_log, Request, Response, RouteContext, Url};

async fn create_video_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    console_log!("Starting video creation");

    let user_id = auth::extract_user_from_request(&req)?;
    console_log!("User authenticated: {}", user_id);

    rate_limit::check_rate_limit(&ctx.env, &user_id).await?;
    console_log!("Rate limit check passed");

    let body: CreateVideoRequest = req.json().await.map_err(|e| {
        console_log!("Failed to parse request body: {:?}", e);
        AppError::BadRequest("Invalid request body".into())
    })?;
    console_log!("Request body parsed: model={}, size={}, seconds={}", body.model, body.size, body.seconds);

    pricing::validate_video_params(&body.model, &body.size, body.seconds)?;
    console_log!("Video params validated");

    let credits_cost = pricing::calculate_credits(&body.model, body.seconds)?;
    console_log!("Credits cost calculated: {}", credits_cost);

    let video_id = uuid::Uuid::new_v4().to_string();
    console_log!("Generated video ID: {}", video_id);

    console_log!("Deducting {} credits from user {}", credits_cost, user_id);
    let new_balance = credits::deduct_credits_with_lock(
        &ctx.env,
        &user_id,
        &video_id,
        credits_cost,
    )
    .await?;
    console_log!("Credits deducted. New balance: {}", new_balance);

    let result = async {
        console_log!("Calling OpenAI API to create video");
        let openai_response = openai_client::create_video(
            &ctx.env,
            &body.model,
            &body.prompt,
            &body.size,
            body.seconds,
        )
        .await?;
        console_log!("OpenAI video created successfully: {}", openai_response.id);

        let video = Video::new(
            user_id.clone(),
            openai_response.id.clone(),
            body.model,
            body.prompt,
            body.size,
            body.seconds,
            credits_cost,
        );

        console_log!("Inserting video into database");
        db::insert_video(&ctx.env, &video).await?;
        console_log!("Video inserted successfully");

        let response = CreateVideoResponse {
            id: video.id,
            status: video.status,
            credits_cost,
            new_balance,
            estimated_wait_seconds: 120,
        };

        Ok::<_, AppError>(response)
    }
    .await;

    match result {
        Ok(response) => {
            credits::release_lock(&ctx.env, &user_id).await?;
            console_log!("Video creation completed successfully");
            Response::from_json(&response).map_err(|e| e.into())
        }
        Err(e) => {
            console_log!("Video creation failed: {:?}", e);
            credits::refund_credits(&ctx.env, &user_id, &video_id, credits_cost).await?;
            credits::release_lock(&ctx.env, &user_id).await?;
            Err(e)
        }
    }
}

pub async fn create_video(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    create_video_inner(req, ctx).await.or_else(|e| {
        console_log!("Video creation error: {:?}", e);
        e.to_response()
    })
}

async fn get_video_inner(req: Request, ctx: RouteContext<()>) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;
    let video_id = ctx
        .param("id")
        .ok_or_else(|| AppError::BadRequest("Missing video ID".into()))?;

    let mut video = db::get_video_by_id(&ctx.env, video_id).await?;

    if video.user_id != user_id {
        return Err(AppError::NotFound("Video not found".into()));
    }

    if video.status == crate::models::VideoStatus::Queued || video.status == crate::models::VideoStatus::InProgress {
        console_log!("Polling OpenAI for video status: {}", video.openai_video_id);

        match openai_client::get_video_status(&ctx.env, &video.openai_video_id).await {
            Ok(openai_response) => {
                console_log!("OpenAI status: {}, progress: {:?}", openai_response.status, openai_response.progress);

                match openai_response.status.as_str() {
                    "in_progress" => {
                        let progress = openai_response.progress.unwrap_or(0);
                        db::update_video_progress(&ctx.env, &video.openai_video_id, "in_progress", progress).await?;
                        console_log!("Updated video progress to {}%", progress);
                    }
                    "completed" => {
                        let service_url = ctx.env
                            .var("SERVICE_URL")
                            .map_err(|_| AppError::InternalError("SERVICE_URL not configured".into()))?
                            .to_string();

                        let video_url = format!("{}/v1/videos/{}/proxy?variant=video&user_id={}", service_url, video.openai_video_id, video.user_id);
                        let thumbnail_url = format!("{}/v1/videos/{}/proxy?variant=thumbnail&user_id={}", service_url, video.openai_video_id, video.user_id);
                        let spritesheet_url = format!("{}/v1/videos/{}/proxy?variant=spritesheet&user_id={}", service_url, video.openai_video_id, video.user_id);

                        db::update_video_completed(
                            &ctx.env,
                            &video.openai_video_id,
                            &video_url,
                            &thumbnail_url,
                            &spritesheet_url,
                        ).await?;
                        console_log!("Video completed: {}", video.openai_video_id);
                    }
                    "failed" => {
                        let error_msg = openai_response
                            .error
                            .map(|e| e.message)
                            .unwrap_or_else(|| "Unknown error".to_string());

                        db::update_video_failed(&ctx.env, &video.openai_video_id, &error_msg).await?;
                        console_log!("Video failed: {}", error_msg);
                    }
                    _ => {
                        console_log!("Status unchanged: {}", openai_response.status);
                    }
                }

                video = db::get_video_by_id(&ctx.env, video_id).await?;
            }
            Err(e) => {
                console_log!("Failed to poll OpenAI status: {:?}", e);
            }
        }
    }

    Response::from_json(&video).map_err(|e| e.into())
}

pub async fn get_video(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    get_video_inner(req, ctx).await.or_else(|e| e.to_response())
}

async fn list_videos_inner(req: Request, ctx: RouteContext<()>) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;

    let url = req.url()?;
    let limit = get_query_param(&url, "limit")
        .and_then(|s| s.parse::<i32>().ok())
        .unwrap_or(20)
        .min(100);

    let offset = get_query_param(&url, "offset")
        .and_then(|s| s.parse::<i32>().ok())
        .unwrap_or(0);

    let (videos, total_count) = db::list_user_videos(&ctx.env, &user_id, limit, offset).await?;

    let has_more = (offset + limit) < total_count as i32;

    let response = VideoListResponse {
        videos,
        has_more,
        total_count,
    };

    Response::from_json(&response).map_err(|e| e.into())
}

pub async fn list_videos(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    list_videos_inner(req, ctx).await.or_else(|e| e.to_response())
}

async fn estimate_cost_inner(
    mut req: Request,
    _ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;

    let body: EstimateRequest = req.json().await.map_err(|_| {
        AppError::BadRequest("Invalid request body".into())
    })?;

    pricing::validate_video_params(&body.model, &body.size, body.seconds)?;

    let credits_cost = pricing::calculate_credits(&body.model, body.seconds)?;

    let user = db::get_user_by_id(&_ctx.env, &user_id).await?;

    let response = EstimateResponse {
        credits_cost,
        usd_equivalent: pricing::credits_to_usd(credits_cost),
        current_balance: user.credits_balance,
        sufficient_credits: user.credits_balance >= credits_cost,
    };

    Response::from_json(&response).map_err(|e| e.into())
}

pub async fn estimate_cost(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    estimate_cost_inner(req, ctx).await.or_else(|e| e.to_response())
}

fn get_query_param(url: &Url, key: &str) -> Option<String> {
    url.query_pairs()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.to_string())
}
