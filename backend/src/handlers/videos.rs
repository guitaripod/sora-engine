use crate::auth;
use crate::credits;
use crate::db;
use crate::error::AppError;
use crate::models::{CreateVideoRequest, CreateVideoResponse, EstimateRequest, EstimateResponse, VideoListResponse, Video};
use crate::openai_client;
use crate::pricing;
use crate::rate_limit;
use worker::{Request, Response, RouteContext, Url};

async fn create_video_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;

    rate_limit::check_rate_limit(&ctx.env, &user_id).await?;

    let body: CreateVideoRequest = req.json().await.map_err(|_| {
        AppError::BadRequest("Invalid request body".into())
    })?;

    pricing::validate_video_params(&body.model, &body.size, body.seconds)?;

    let credits_cost = pricing::calculate_credits(&body.model, body.seconds)?;

    let video_id = uuid::Uuid::new_v4().to_string();

    let new_balance = credits::deduct_credits_with_lock(
        &ctx.env,
        &user_id,
        &video_id,
        credits_cost,
    )
    .await?;

    let openai_response = match openai_client::create_video(
        &ctx.env,
        &body.model,
        &body.prompt,
        &body.size,
        body.seconds,
    )
    .await
    {
        Ok(resp) => resp,
        Err(e) => {
            credits::refund_credits(&ctx.env, &user_id, &video_id, credits_cost).await?;
            credits::release_lock(&ctx.env, &user_id).await?;
            return Err(e);
        }
    };

    let video = Video::new(
        user_id.clone(),
        openai_response.id.clone(),
        body.model,
        body.prompt,
        body.size,
        body.seconds,
        credits_cost,
    );

    db::insert_video(&ctx.env, &video).await?;

    credits::release_lock(&ctx.env, &user_id).await?;

    let response = CreateVideoResponse {
        id: video.id,
        status: video.status,
        credits_cost,
        new_balance,
        estimated_wait_seconds: 120,
    };

    Response::from_json(&response).map_err(|e| e.into())
}

pub async fn create_video(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    create_video_inner(req, ctx).await.or_else(|e| e.to_response())
}

async fn get_video_inner(req: Request, ctx: RouteContext<()>) -> Result<Response, AppError> {
    let user_id = auth::extract_user_from_request(&req)?;
    let video_id = ctx
        .param("id")
        .ok_or_else(|| AppError::BadRequest("Missing video ID".into()))?;

    let video = db::get_video_by_id(&ctx.env, video_id).await?;

    if video.user_id != user_id {
        return Err(AppError::NotFound("Video not found".into()));
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
