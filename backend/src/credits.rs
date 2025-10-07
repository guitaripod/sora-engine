use crate::db;
use crate::error::AppError;
use worker::Env;
use chrono::DateTime;

fn now_rfc3339() -> String {
    let ms = worker::Date::now().as_millis();
    let secs = (ms / 1000) as i64;
    let nsecs = ((ms % 1000) * 1_000_000) as u32;
    DateTime::from_timestamp(secs, nsecs)
        .unwrap_or_else(|| DateTime::from_timestamp(0, 0).unwrap())
        .to_rfc3339()
}

pub async fn deduct_credits_with_lock(
    env: &Env,
    user_id: &str,
    video_id: &str,
    amount: i64,
) -> Result<i64, AppError> {
    let database = env
        .d1("DB")
        .map_err(|e| AppError::InternalError(format!("Failed to get DB: {}", e)))?;

    database
        .prepare("INSERT INTO user_locks (user_id, video_id) VALUES (?, ?)")
        .bind(&[user_id.into(), video_id.into()])?
        .run()
        .await
        .map_err(|_| AppError::ConcurrentGeneration)?;

    let user = db::get_user_by_id(env, user_id).await?;

    if user.credits_balance < amount {
        release_lock(env, user_id).await?;
        return Err(AppError::InsufficientCredits);
    }

    let new_balance = user.credits_balance - amount;

    database
        .prepare("UPDATE users SET credits_balance = ?, total_videos_generated = total_videos_generated + 1, updated_at = ? WHERE id = ?")
        .bind(&[(new_balance as f64).into(), now_rfc3339().into(), user_id.into()])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    db::insert_transaction(
        env,
        user_id,
        -amount,
        new_balance,
        "video_generation",
        "Video generation cost",
        Some(video_id),
        None,
    )
    .await?;

    Ok(new_balance)
}

pub async fn release_lock(env: &Env, user_id: &str) -> Result<(), AppError> {
    let db = env
        .d1("DB")
        .map_err(|e| AppError::InternalError(format!("Failed to get DB: {}", e)))?;

    db.prepare("DELETE FROM user_locks WHERE user_id = ?")
        .bind(&[user_id.into()])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub async fn add_credits(
    env: &Env,
    user_id: &str,
    amount: i64,
    description: &str,
    revenuecat_transaction_id: Option<&str>,
) -> Result<i64, AppError> {
    let user = db::get_user_by_id(env, user_id).await?;
    let new_balance = user.credits_balance + amount;

    let db = env
        .d1("DB")
        .map_err(|e| AppError::InternalError(format!("Failed to get DB: {}", e)))?;

    db.prepare("UPDATE users SET credits_balance = ?, updated_at = ? WHERE id = ?")
        .bind(&[
            (new_balance as f64).into(),
            now_rfc3339().into(),
            user_id.into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    db::insert_transaction(
        env,
        user_id,
        amount,
        new_balance,
        "purchase",
        description,
        None,
        revenuecat_transaction_id,
    )
    .await?;

    Ok(new_balance)
}

pub async fn refund_credits(
    env: &Env,
    user_id: &str,
    video_id: &str,
    amount: i64,
) -> Result<i64, AppError> {
    let db = env
        .d1("DB")
        .map_err(|e| AppError::InternalError(format!("Failed to get DB: {}", e)))?;

    let existing_refund = db
        .prepare("SELECT id FROM credit_transactions WHERE video_id = ? AND transaction_type = 'refund' LIMIT 1")
        .bind(&[video_id.into()])?
        .first::<String>(None)
        .await;

    if let Ok(Some(_)) = existing_refund {
        let user = db::get_user_by_id(env, user_id).await?;
        return Ok(user.credits_balance);
    }

    let user = db::get_user_by_id(env, user_id).await?;
    let new_balance = user.credits_balance + amount;

    db.prepare("UPDATE users SET credits_balance = ?, updated_at = ? WHERE id = ?")
        .bind(&[
            (new_balance as f64).into(),
            now_rfc3339().into(),
            user_id.into(),
        ])?
        .run()
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    db::insert_transaction(
        env,
        user_id,
        amount,
        new_balance,
        "refund",
        "Video generation failed - credits refunded",
        Some(video_id),
        None,
    )
    .await?;

    Ok(new_balance)
}
