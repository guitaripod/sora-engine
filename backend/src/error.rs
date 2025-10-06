use worker::{Response, Result};
use serde_json::json;

#[derive(Debug)]
pub enum AppError {
    Unauthorized(String),
    BadRequest(String),
    NotFound(String),
    InsufficientCredits,
    ConcurrentGeneration,
    RateLimitExceeded(String),
    ExternalApiError(String),
    DatabaseError(String),
    InternalError(String),
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AppError::Unauthorized(msg) => write!(f, "Unauthorized: {}", msg),
            AppError::BadRequest(msg) => write!(f, "Bad request: {}", msg),
            AppError::NotFound(msg) => write!(f, "Not found: {}", msg),
            AppError::InsufficientCredits => write!(f, "Insufficient credits"),
            AppError::ConcurrentGeneration => write!(f, "Another video is currently being generated"),
            AppError::RateLimitExceeded(msg) => write!(f, "Rate limit exceeded: {}", msg),
            AppError::ExternalApiError(msg) => write!(f, "External API error: {}", msg),
            AppError::DatabaseError(msg) => write!(f, "Database error: {}", msg),
            AppError::InternalError(msg) => write!(f, "Internal error: {}", msg),
        }
    }
}

impl std::error::Error for AppError {}

impl From<worker::Error> for AppError {
    fn from(err: worker::Error) -> Self {
        AppError::InternalError(err.to_string())
    }
}

impl From<serde_json::Error> for AppError {
    fn from(err: serde_json::Error) -> Self {
        AppError::BadRequest(format!("JSON error: {}", err))
    }
}

impl AppError {
    pub fn to_response(&self) -> Result<Response> {
        let (status, error_code, message) = match self {
            AppError::Unauthorized(msg) => (401, "unauthorized", msg.clone()),
            AppError::BadRequest(msg) => (400, "bad_request", msg.clone()),
            AppError::NotFound(msg) => (404, "not_found", msg.clone()),
            AppError::InsufficientCredits => (
                402,
                "insufficient_credits",
                "You don't have enough credits. Purchase more to continue.".to_string(),
            ),
            AppError::ConcurrentGeneration => (
                409,
                "concurrent_generation",
                "You already have a video being generated. Please wait for it to complete.".to_string(),
            ),
            AppError::RateLimitExceeded(msg) => (429, "rate_limit_exceeded", msg.clone()),
            AppError::ExternalApiError(msg) => (502, "external_api_error", msg.clone()),
            AppError::DatabaseError(msg) => (500, "database_error", msg.clone()),
            AppError::InternalError(msg) => (500, "internal_error", msg.clone()),
        };

        let body = json!({
            "error": {
                "code": error_code,
                "message": message
            }
        });

        Response::from_json(&body).map(|r| {
            r.with_status(status)
        })
    }
}
