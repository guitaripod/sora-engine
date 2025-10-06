use crate::error::AppError;
use jwt_simple::prelude::*;
use worker::{Env, Request};

#[derive(Debug, Deserialize)]
struct AppleJWTClaims {
    pub sub: String,
    pub email: Option<String>,
    pub iss: String,
    pub aud: String,
}

pub async fn verify_apple_token(identity_token: &str, env: &Env) -> Result<(String, Option<String>), AppError> {
    let _team_id = env.var("APPLE_TEAM_ID")
        .map_err(|_| AppError::InternalError("APPLE_TEAM_ID not configured".into()))?
        .to_string();

    let client_id = env.var("APPLE_CLIENT_ID")
        .map_err(|_| AppError::InternalError("APPLE_CLIENT_ID not configured".into()))?
        .to_string();

    let parts: Vec<&str> = identity_token.split('.').collect();
    if parts.len() != 3 {
        return Err(AppError::Unauthorized("Invalid token format".into()));
    }

    let payload = parts[1];
    use base64::{Engine as _, engine::general_purpose};
    let decoded = general_purpose::URL_SAFE_NO_PAD.decode(payload)
        .map_err(|_| AppError::Unauthorized("Invalid token encoding".into()))?;

    let claims: AppleJWTClaims = serde_json::from_slice(&decoded)
        .map_err(|_| AppError::Unauthorized("Invalid token claims".into()))?;

    if claims.iss != format!("https://appleid.apple.com") {
        return Err(AppError::Unauthorized("Invalid token issuer".into()));
    }

    if claims.aud != client_id {
        return Err(AppError::Unauthorized("Invalid token audience".into()));
    }

    Ok((claims.sub, claims.email))
}

pub fn extract_user_from_request(req: &Request) -> Result<String, AppError> {
    let auth_header = req
        .headers()
        .get("Authorization")
        .ok()
        .flatten()
        .ok_or_else(|| AppError::Unauthorized("Missing Authorization header".into()))?;

    if !auth_header.starts_with("Bearer ") {
        return Err(AppError::Unauthorized("Invalid Authorization format".into()));
    }

    let user_id = auth_header.trim_start_matches("Bearer ");
    if user_id.is_empty() {
        return Err(AppError::Unauthorized("Empty user ID".into()));
    }

    Ok(user_id.to_string())
}
