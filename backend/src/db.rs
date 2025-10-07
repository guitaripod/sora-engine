use crate::error::AppError;
use crate::models::{User, Video, CreditTransaction};
use worker::{Env, D1Database, wasm_bindgen::JsValue};
use chrono::{DateTime, Utc};
use serde::Deserialize;

fn now_datetime() -> DateTime<Utc> {
    let ms = worker::Date::now().as_millis();
    let secs = (ms / 1000) as i64;
    let nsecs = ((ms % 1000) * 1_000_000) as u32;
    DateTime::from_timestamp(secs, nsecs)
        .unwrap_or_else(|| DateTime::from_timestamp(0, 0).unwrap())
}

fn now_rfc3339() -> String {
    now_datetime().to_rfc3339()
}

#[derive(Deserialize)]
struct CountResult {
    count: f64,
}

pub async fn get_or_create_user(
    env: &Env,
    apple_user_id: &str,
    email: Option<String>,
) -> Result<(User, bool), AppError> {
    let db = get_db(env)?;

    let existing = db
        .prepare("SELECT id, apple_user_id, email, credits_balance, total_videos_generated, created_at, updated_at FROM users WHERE apple_user_id = ?")
        .bind(&[apple_user_id.into()])?
        .first::<serde_json::Value>(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    if let Some(user_data) = existing {
        let user = User {
            id: user_data.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
            apple_user_id: user_data.get("apple_user_id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
            email: user_data.get("email").and_then(|v| v.as_str()).map(|s| s.to_string()),
            credits_balance: user_data.get("credits_balance").and_then(|v| v.as_f64()).unwrap_or(0.0) as i64,
            total_videos_generated: user_data.get("total_videos_generated").and_then(|v| v.as_f64()).unwrap_or(0.0) as i64,
            created_at: user_data.get("created_at").and_then(|v| v.as_str()).and_then(|s| s.parse().ok()).unwrap_or_else(|| now_datetime()),
            updated_at: user_data.get("updated_at").and_then(|v| v.as_str()).and_then(|s| s.parse().ok()).unwrap_or_else(|| now_datetime()),
        };
        return Ok((user, false));
    }

    use crate::pricing::WELCOME_CREDITS;

    let now = now_datetime();
    let mut user = User::new(apple_user_id.to_string(), email.clone(), now);
    user.credits_balance = WELCOME_CREDITS;

    let created_at_str = user.created_at.to_rfc3339();
    let updated_at_str = user.updated_at.to_rfc3339();

    db.prepare("INSERT INTO users (id, apple_user_id, email, credits_balance, total_videos_generated, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
        .bind(&[
            user.id.clone().into(),
            user.apple_user_id.clone().into(),
            email.unwrap_or_default().into(),
            (user.credits_balance as f64).into(),
            (user.total_videos_generated as f64).into(),
            created_at_str.into(),
            updated_at_str.into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    let transaction_id = uuid::Uuid::new_v4().to_string();
    db.prepare("INSERT INTO credit_transactions (id, user_id, amount, balance_after, transaction_type, description, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
        .bind(&[
            transaction_id.into(),
            user.id.clone().into(),
            (WELCOME_CREDITS as f64).into(),
            (WELCOME_CREDITS as f64).into(),
            "welcome".into(),
            "Welcome bonus - Try your first video for free!".into(),
            now_rfc3339().into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    Ok((user, true))
}

pub async fn get_user_by_id(env: &Env, user_id: &str) -> Result<User, AppError> {
    let db = get_db(env)?;

    let user_data = db.prepare("SELECT id, apple_user_id, email, credits_balance, total_videos_generated, created_at, updated_at FROM users WHERE id = ?")
        .bind(&[user_id.into()])?
        .first::<serde_json::Value>(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("User not found".into()))?;

    Ok(User {
        id: user_data.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        apple_user_id: user_data.get("apple_user_id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        email: user_data.get("email").and_then(|v| v.as_str()).map(|s| s.to_string()),
        credits_balance: user_data.get("credits_balance").and_then(|v| v.as_f64()).unwrap_or(0.0) as i64,
        total_videos_generated: user_data.get("total_videos_generated").and_then(|v| v.as_f64()).unwrap_or(0.0) as i64,
        created_at: user_data.get("created_at").and_then(|v| v.as_str()).and_then(|s| s.parse().ok()).unwrap_or_else(|| now_datetime()),
        updated_at: user_data.get("updated_at").and_then(|v| v.as_str()).and_then(|s| s.parse().ok()).unwrap_or_else(|| now_datetime()),
    })
}

pub async fn insert_video(env: &Env, video: &Video) -> Result<(), AppError> {
    let db = get_db(env)?;

    db.prepare("INSERT INTO videos (id, user_id, openai_video_id, status, model, prompt, size, seconds, credits_cost, progress, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
        .bind(&[
            video.id.clone().into(),
            video.user_id.clone().into(),
            video.openai_video_id.clone().into(),
            video.status.to_string().into(),
            video.model.clone().into(),
            video.prompt.clone().into(),
            video.size.clone().into(),
            video.seconds.into(),
            (video.credits_cost as f64).into(),
            video.progress.into(),
            video.created_at.to_rfc3339().into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub async fn get_video_by_id(env: &Env, video_id: &str) -> Result<Video, AppError> {
    let db = get_db(env)?;

    db.prepare("SELECT id, user_id, openai_video_id, status, model, prompt, size, seconds, video_url, thumbnail_url, spritesheet_url, download_url_expires_at, credits_cost, progress, created_at, completed_at, failed_at, error_message FROM videos WHERE id = ?")
        .bind(&[video_id.into()])?
        .first(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("Video not found".into()))
}

pub async fn get_video_by_openai_id(env: &Env, openai_video_id: &str) -> Result<Video, AppError> {
    let db = get_db(env)?;

    db.prepare("SELECT id, user_id, openai_video_id, status, model, prompt, size, seconds, video_url, thumbnail_url, spritesheet_url, download_url_expires_at, credits_cost, progress, created_at, completed_at, failed_at, error_message FROM videos WHERE openai_video_id = ?")
        .bind(&[openai_video_id.into()])?
        .first(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("Video not found".into()))
}

pub async fn update_video_progress(
    env: &Env,
    openai_video_id: &str,
    status: &str,
    progress: i32,
) -> Result<(), AppError> {
    let db = get_db(env)?;

    db.prepare("UPDATE videos SET status = ?, progress = ? WHERE openai_video_id = ?")
        .bind(&[status.into(), progress.into(), openai_video_id.into()])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub async fn update_video_completed(
    env: &Env,
    openai_video_id: &str,
    video_url: &str,
    thumbnail_url: &str,
    spritesheet_url: &str,
) -> Result<(), AppError> {
    let db = get_db(env)?;
    let now = now_datetime();
    let expires_at = now + chrono::Duration::hours(24);

    db.prepare("UPDATE videos SET status = ?, video_url = ?, thumbnail_url = ?, spritesheet_url = ?, download_url_expires_at = ?, completed_at = ?, progress = 100 WHERE openai_video_id = ?")
        .bind(&[
            "completed".into(),
            video_url.into(),
            thumbnail_url.into(),
            spritesheet_url.into(),
            expires_at.to_rfc3339().into(),
            now.to_rfc3339().into(),
            openai_video_id.into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub async fn update_video_failed(
    env: &Env,
    openai_video_id: &str,
    error_message: &str,
) -> Result<(), AppError> {
    let db = get_db(env)?;
    let now = now_datetime();

    db.prepare("UPDATE videos SET status = ?, error_message = ?, failed_at = ? WHERE openai_video_id = ?")
        .bind(&[
            "failed".into(),
            error_message.into(),
            now.to_rfc3339().into(),
            openai_video_id.into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub async fn list_user_videos(
    env: &Env,
    user_id: &str,
    limit: i32,
    offset: i32,
) -> Result<(Vec<Video>, i64), AppError> {
    let db = get_db(env)?;

    let videos: Vec<Video> = db
        .prepare("SELECT id, user_id, openai_video_id, status, model, prompt, size, seconds, video_url, thumbnail_url, spritesheet_url, download_url_expires_at, credits_cost, progress, created_at, completed_at, failed_at, error_message FROM videos WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?")
        .bind(&[user_id.into(), limit.into(), offset.into()])?
        .all()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?
        .results::<Video>()
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    let count_result: Option<CountResult> = db
        .prepare("SELECT COUNT(*) as count FROM videos WHERE user_id = ?")
        .bind(&[user_id.into()])?
        .first(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    let total = count_result.map(|r| r.count as i64).unwrap_or(0);

    Ok((videos, total))
}

pub async fn insert_transaction(
    env: &Env,
    user_id: &str,
    amount: i64,
    balance_after: i64,
    transaction_type: &str,
    description: &str,
    video_id: Option<&str>,
    apple_transaction_id: Option<&str>,
) -> Result<(), AppError> {
    let db = get_db(env)?;
    let transaction_id = uuid::Uuid::new_v4().to_string();

    db.prepare("INSERT INTO credit_transactions (id, user_id, amount, balance_after, transaction_type, description, video_id, revenuecat_transaction_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
        .bind(&[
            transaction_id.into(),
            user_id.into(),
            (amount as f64).into(),
            (balance_after as f64).into(),
            transaction_type.into(),
            description.into(),
            video_id.map(|v| JsValue::from_str(v)).unwrap_or(JsValue::NULL),
            apple_transaction_id.map(|v| JsValue::from_str(v)).unwrap_or(JsValue::NULL),
            now_rfc3339().into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub async fn get_user_transactions(
    env: &Env,
    user_id: &str,
    limit: i32,
) -> Result<Vec<CreditTransaction>, AppError> {
    let db = get_db(env)?;

    db.prepare("SELECT id, user_id, amount, balance_after, transaction_type, description, video_id, revenuecat_transaction_id, metadata, created_at FROM credit_transactions WHERE user_id = ? ORDER BY created_at DESC LIMIT ?")
        .bind(&[user_id.into(), limit.into()])?
        .all()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?
        .results::<CreditTransaction>()
        .map_err(|e| AppError::DatabaseError(e.to_string()))
}

fn get_db(env: &Env) -> Result<D1Database, AppError> {
    env.d1("DB")
        .map_err(|e| AppError::InternalError(format!("Failed to get DB: {}", e)))
}
