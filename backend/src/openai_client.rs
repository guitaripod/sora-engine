use crate::error::AppError;
use crate::models::OpenAIVideoResponse;
use worker::{Env, Fetch, Headers, Method, Request, RequestInit};

pub async fn create_video(
    env: &Env,
    model: &str,
    prompt: &str,
    size: &str,
    seconds: i32,
) -> Result<OpenAIVideoResponse, AppError> {
    let api_key = env
        .secret("OPENAI_API_KEY")
        .map_err(|_| AppError::InternalError("OPENAI_API_KEY not configured".into()))?
        .to_string();

    let url = "https://api.openai.com/v1/videos";

    let form_data = format!(
        "--boundary\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n{}\r\n\
        --boundary\r\nContent-Disposition: form-data; name=\"prompt\"\r\n\r\n{}\r\n\
        --boundary\r\nContent-Disposition: form-data; name=\"size\"\r\n\r\n{}\r\n\
        --boundary\r\nContent-Disposition: form-data; name=\"seconds\"\r\n\r\n{}\r\n\
        --boundary--\r\n",
        model, prompt, size, seconds
    );

    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {}", api_key))?;
    headers.set("Content-Type", "multipart/form-data; boundary=boundary")?;

    let request = Request::new_with_init(
        url,
        &RequestInit::new()
            .with_method(Method::Post)
            .with_headers(headers)
            .with_body(Some(form_data.into())),
    )?;

    let mut response = Fetch::Request(request).send().await?;
    let text = response.text().await?;

    if response.status_code() < 200 || response.status_code() >= 300 {
        return Err(AppError::ExternalApiError(format!(
            "OpenAI API error ({}): {}",
            response.status_code(),
            text
        )));
    }

    serde_json::from_str(&text).map_err(|e| {
        AppError::ExternalApiError(format!("Failed to parse OpenAI response: {}", e))
    })
}

pub async fn get_video_status(
    env: &Env,
    video_id: &str,
) -> Result<OpenAIVideoResponse, AppError> {
    let api_key = env
        .secret("OPENAI_API_KEY")
        .map_err(|_| AppError::InternalError("OPENAI_API_KEY not configured".into()))?
        .to_string();

    let url = format!("https://api.openai.com/v1/videos/{}", video_id);

    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {}", api_key))?;

    let request = Request::new_with_init(
        &url,
        &RequestInit::new()
            .with_method(Method::Get)
            .with_headers(headers),
    )?;

    let mut response = Fetch::Request(request).send().await?;
    let text = response.text().await?;

    if response.status_code() < 200 || response.status_code() >= 300 {
        return Err(AppError::ExternalApiError(format!(
            "OpenAI API error ({}): {}",
            response.status_code(),
            text
        )));
    }

    serde_json::from_str(&text).map_err(|e| {
        AppError::ExternalApiError(format!("Failed to parse OpenAI response: {}", e))
    })
}

pub fn build_download_url(video_id: &str, variant: &str) -> String {
    format!(
        "https://api.openai.com/v1/videos/{}/content?variant={}",
        video_id, variant
    )
}
