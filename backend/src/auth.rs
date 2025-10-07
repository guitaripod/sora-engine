use crate::error::AppError;
use jwt_simple::prelude::*;
use worker::{Env, Request};

#[derive(Debug, Serialize, Deserialize)]
struct AppleJWTClaims {
    pub email: Option<String>,
    #[serde(default)]
    pub email_verified: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct ApplePublicKey {
    #[allow(dead_code)]
    kty: String,
    kid: String,
    #[serde(rename = "use")]
    #[allow(dead_code)]
    use_field: String,
    #[allow(dead_code)]
    alg: String,
    n: String,
    e: String,
}

#[derive(Debug, Deserialize)]
struct ApplePublicKeys {
    keys: Vec<ApplePublicKey>,
}

pub async fn verify_apple_token(identity_token: &str, env: &Env) -> Result<(String, Option<String>), AppError> {
    let client_id = env.var("APPLE_CLIENT_ID")
        .map_err(|_| AppError::InternalError("APPLE_CLIENT_ID not configured".into()))?
        .to_string();

    let parts: Vec<&str> = identity_token.split('.').collect();
    if parts.len() != 3 {
        return Err(AppError::Unauthorized("Invalid token format".into()));
    }

    let header_json = decode_jwt_part(parts[0])?;
    let header: serde_json::Value = serde_json::from_slice(&header_json)
        .map_err(|_| AppError::Unauthorized("Invalid token header".into()))?;

    let kid = header.get("kid")
        .and_then(|v| v.as_str())
        .ok_or_else(|| AppError::Unauthorized("Missing kid in token header".into()))?;

    let public_keys = fetch_apple_public_keys().await?;

    let matching_key = public_keys.keys.iter()
        .find(|k| k.kid == kid)
        .ok_or_else(|| AppError::Unauthorized("No matching public key found".into()))?;

    use base64::{Engine as _, engine::general_purpose};
    let n_bytes = general_purpose::URL_SAFE_NO_PAD.decode(&matching_key.n)
        .map_err(|_| AppError::Unauthorized("Invalid key modulus".into()))?;
    let e_bytes = general_purpose::URL_SAFE_NO_PAD.decode(&matching_key.e)
        .map_err(|_| AppError::Unauthorized("Invalid key exponent".into()))?;

    let public_key = RS256PublicKey::from_components(&n_bytes, &e_bytes)
        .map_err(|_| AppError::Unauthorized("Invalid public key".into()))?;

    let token_data = public_key.verify_token::<AppleJWTClaims>(identity_token, None)
        .map_err(|_| AppError::Unauthorized("Token signature verification failed".into()))?;

    let claims = token_data.custom;

    let sub = token_data.subject
        .ok_or_else(|| AppError::Unauthorized("Missing subject".into()))?;
    let exp = token_data.expires_at
        .ok_or_else(|| AppError::Unauthorized("Missing expiration time".into()))?
        .as_secs();
    let iat = token_data.issued_at
        .ok_or_else(|| AppError::Unauthorized("Missing issued at time".into()))?
        .as_secs();
    let iss = token_data.issuer
        .ok_or_else(|| AppError::Unauthorized("Missing issuer".into()))?;
    let aud = token_data.audiences
        .ok_or_else(|| AppError::Unauthorized("Missing audience".into()))?;

    let now = (worker::Date::now().as_millis() / 1000) as u64;

    if exp < now {
        return Err(AppError::Unauthorized("Token expired".into()));
    }

    if iat > now + 60 {
        return Err(AppError::Unauthorized("Token issued in the future".into()));
    }

    if iss != "https://appleid.apple.com" {
        return Err(AppError::Unauthorized("Invalid token issuer".into()));
    }

    let mut allowed_audiences = std::collections::HashSet::new();
    allowed_audiences.insert(client_id.clone());

    if !aud.contains(&allowed_audiences) {
        return Err(AppError::Unauthorized("Invalid token audience".into()));
    }

    Ok((sub, claims.email))
}

fn decode_jwt_part(part: &str) -> Result<Vec<u8>, AppError> {
    use base64::{Engine as _, engine::general_purpose};
    general_purpose::URL_SAFE_NO_PAD.decode(part)
        .map_err(|_| AppError::Unauthorized("Invalid token encoding".into()))
}

async fn fetch_apple_public_keys() -> Result<ApplePublicKeys, AppError> {
    let mut response = worker::Fetch::Url("https://appleid.apple.com/auth/keys".parse()
        .map_err(|_| AppError::InternalError("Invalid Apple keys URL".into()))?)
        .send()
        .await
        .map_err(|_| AppError::ExternalApiError("Failed to fetch Apple public keys".into()))?;

    if response.status_code() != 200 {
        return Err(AppError::ExternalApiError("Apple keys endpoint returned non-200 status".into()));
    }

    response.json().await
        .map_err(|_| AppError::ExternalApiError("Failed to parse Apple public keys".into()))
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
