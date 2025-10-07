use crate::auth;
use crate::db;
use crate::error::AppError;
use worker::{Request, Response, RouteContext};

async fn proxy_video_content_inner(
    req: Request,
    ctx: RouteContext<()>,
) -> Result<Response, AppError> {
    let url = req.url()?;

    let user_id = match auth::extract_user_from_request(&req) {
        Ok(uid) => uid,
        Err(_) => {
            url.query_pairs()
                .find(|(k, _)| k == "user_id")
                .map(|(_, v)| v.to_string())
                .ok_or_else(|| AppError::Unauthorized("Missing authentication".into()))?
        }
    };

    let path_segments: Vec<&str> = url.path_segments().ok_or_else(|| {
        AppError::BadRequest("Invalid URL".into())
    })?.collect();

    let openai_video_id = path_segments.get(2).ok_or_else(|| {
        AppError::BadRequest("Missing video ID".into())
    })?;

    let video = db::get_video_by_openai_id(&ctx.env, openai_video_id).await?;

    if video.user_id != user_id {
        return Err(AppError::Unauthorized("Not authorized to access this video".into()));
    }

    let url_string = req.url()?.to_string();
    let variant = if url_string.contains("variant=thumbnail") {
        "thumbnail"
    } else if url_string.contains("variant=spritesheet") {
        "spritesheet"
    } else {
        "video"
    };

    let api_key = ctx.env
        .secret("OPENAI_API_KEY")
        .map_err(|_| AppError::InternalError("OPENAI_API_KEY not configured".into()))?
        .to_string();

    let download_url = format!(
        "https://api.openai.com/v1/videos/{}/content?variant={}",
        openai_video_id, variant
    );

    if req.method() == worker::Method::Head {
        let headers = worker::Headers::new();
        headers.set("Authorization", &format!("Bearer {}", api_key))?;
        headers.set("Range", "bytes=0-0")?;

        let range_req = Request::new_with_init(
            &download_url,
            &worker::RequestInit::new()
                .with_method(worker::Method::Get)
                .with_headers(headers),
        )?;

        let openai_response = worker::Fetch::Request(range_req).send().await?;

        let mut resp = Response::ok("")?;
        resp.headers_mut().set("Content-Type", "video/mp4")?;
        resp.headers_mut().set("Accept-Ranges", "bytes")?;

        if let Some(content_length) = openai_response.headers().get("Content-Length")? {
            resp.headers_mut().set("Content-Length", &content_length)?;
        } else if let Some(range) = openai_response.headers().get("Content-Range")? {
            if let Some(total) = range.split('/').last() {
                resp.headers_mut().set("Content-Length", total)?;
            }
        }

        resp.headers_mut().set("Cache-Control", "public, max-age=86400")?;
        return Ok(resp);
    }

    let headers = worker::Headers::new();
    headers.set("Authorization", &format!("Bearer {}", api_key))?;

    let download_req = Request::new_with_init(
        &download_url,
        &worker::RequestInit::new()
            .with_method(worker::Method::Get)
            .with_headers(headers),
    )?;

    let mut openai_response = worker::Fetch::Request(download_req).send().await?;

    if openai_response.status_code() < 200 || openai_response.status_code() >= 300 {
        let error_text = openai_response.text().await.unwrap_or_else(|_| "Unknown error".into());
        return Err(AppError::ExternalApiError(format!(
            "Failed to download from OpenAI ({}): {}",
            openai_response.status_code(),
            error_text
        )));
    }

    let body = openai_response.bytes().await?;
    let total_length = body.len();

    let range_header = req.headers().get("Range")?;

    if let Some(range_str) = range_header {
        if let Some(range_value) = range_str.strip_prefix("bytes=") {
            if let Some((start_str, end_str)) = range_value.split_once('-') {
                let start: usize = start_str.parse().unwrap_or(0);
                let end: usize = if end_str.is_empty() {
                    total_length - 1
                } else {
                    end_str.parse().unwrap_or(total_length - 1).min(total_length - 1)
                };

                let range_body = &body[start..=end];
                let mut resp = Response::from_bytes(range_body.to_vec())?.with_status(206);

                resp.headers_mut().set("Content-Type", "video/mp4")?;
                resp.headers_mut().set("Content-Length", &(end - start + 1).to_string())?;
                resp.headers_mut().set("Content-Range", &format!("bytes {}-{}/{}", start, end, total_length))?;
                resp.headers_mut().set("Accept-Ranges", "bytes")?;
                resp.headers_mut().set("Cache-Control", "public, max-age=86400")?;

                return Ok(resp);
            }
        }
    }

    let mut resp = Response::from_bytes(body)?;
    resp.headers_mut().set("Content-Type", "video/mp4")?;
    resp.headers_mut().set("Content-Length", &total_length.to_string())?;
    resp.headers_mut().set("Accept-Ranges", "bytes")?;
    resp.headers_mut().set("Cache-Control", "public, max-age=86400")?;

    Ok(resp)
}

pub async fn proxy_video_content(req: Request, ctx: RouteContext<()>) -> worker::Result<Response> {
    proxy_video_content_inner(req, ctx).await.or_else(|e| e.to_response())
}
