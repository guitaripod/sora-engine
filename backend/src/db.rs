use crate::error::AppError;
use crate::models::{User, Video, CreditTransaction};
use worker::{Env, D1Database};
use chrono::Utc;

pub async fn get_or_create_user(
    env: &Env,
    apple_user_id: &str,
    email: Option<String>,
) -> Result<(User, bool), AppError> {
    let db = get_db(env)?;

    let existing: Option<User> = db
        .prepare("SELECT id, apple_user_id, email, credits_balance, total_videos_generated, created_at, updated_at FROM users WHERE apple_user_id = ?")
        .bind(&[apple_user_id.into()])?
        .first(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    if let Some(user) = existing {
        return Ok((user, false));
    }

    let user = User::new(apple_user_id.to_string(), email.clone());

    db.prepare("INSERT INTO users (id, apple_user_id, email, credits_balance, total_videos_generated, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
        .bind(&[
            user.id.clone().into(),
            user.apple_user_id.clone().into(),
            email.unwrap_or_default().into(),
            user.credits_balance.into(),
            user.total_videos_generated.into(),
            user.created_at.to_rfc3339().into(),
            user.updated_at.to_rfc3339().into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    Ok((user, true))
}

pub async fn get_user_by_id(env: &Env, user_id: &str) -> Result<User, AppError> {
    let db = get_db(env)?;

    db.prepare("SELECT id, apple_user_id, email, credits_balance, total_videos_generated, created_at, updated_at FROM users WHERE id = ?")
        .bind(&[user_id.into()])?
        .first(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("User not found".into()))
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
            video.credits_cost.into(),
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
    let now = Utc::now();
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
    let now = Utc::now();

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

    let total: i64 = db
        .prepare("SELECT COUNT(*) as count FROM videos WHERE user_id = ?")
        .bind(&[user_id.into()])?
        .first::<i64>(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?
        .unwrap_or(0);

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
    revenuecat_transaction_id: Option<&str>,
) -> Result<(), AppError> {
    let db = get_db(env)?;
    let transaction_id = uuid::Uuid::new_v4().to_string();

    db.prepare("INSERT INTO credit_transactions (id, user_id, amount, balance_after, transaction_type, description, video_id, revenuecat_transaction_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
        .bind(&[
            transaction_id.into(),
            user_id.into(),
            amount.into(),
            balance_after.into(),
            transaction_type.into(),
            description.into(),
            video_id.unwrap_or("").into(),
            revenuecat_transaction_id.unwrap_or("").into(),
            Utc::now().to_rfc3339().into(),
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
