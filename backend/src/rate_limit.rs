use crate::error::AppError;
use worker::Env;
use chrono::DateTime;
use serde::Deserialize;

fn today_date() -> String {
    let ms = worker::Date::now().as_millis();
    let secs = (ms / 1000) as i64;
    let nsecs = ((ms % 1000) * 1_000_000) as u32;
    DateTime::from_timestamp(secs, nsecs)
        .unwrap_or_else(|| DateTime::from_timestamp(0, 0).unwrap())
        .format("%Y-%m-%d")
        .to_string()
}

#[derive(Deserialize)]
struct CountResult {
    count: f64,
}

pub async fn check_rate_limit(env: &Env, user_id: &str) -> Result<(), AppError> {
    let max_per_day = env
        .var("MAX_VIDEOS_PER_DAY")
        .map(|v| v.to_string().parse::<i64>().unwrap_or(20))
        .unwrap_or(20);

    let db = env
        .d1("DB")
        .map_err(|e| AppError::InternalError(format!("Failed to get DB: {}", e)))?;

    let today = today_date();

    let count_result: Option<CountResult> = db
        .prepare("SELECT COUNT(*) as count FROM videos WHERE user_id = ? AND DATE(created_at) = ?")
        .bind(&[user_id.into(), today.into()])?
        .first(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    let count = count_result.map(|r| r.count as i64).unwrap_or(0);

    if count >= max_per_day {
        return Err(AppError::RateLimitExceeded(format!(
            "Daily limit of {} videos reached. Limit resets at midnight UTC.",
            max_per_day
        )));
    }

    Ok(())
}

#[allow(dead_code)]
pub async fn get_rate_limit_status(env: &Env, user_id: &str) -> Result<(i64, i64), AppError> {
    let max_per_day = env
        .var("MAX_VIDEOS_PER_DAY")
        .map(|v| v.to_string().parse::<i64>().unwrap_or(20))
        .unwrap_or(20);

    let db = env
        .d1("DB")
        .map_err(|e| AppError::InternalError(format!("Failed to get DB: {}", e)))?;

    let today = today_date();

    let count_result: Option<CountResult> = db
        .prepare("SELECT COUNT(*) as count FROM videos WHERE user_id = ? AND DATE(created_at) = ?")
        .bind(&[user_id.into(), today.into()])?
        .first(None)
        .await
        .map_err(|e| AppError::DatabaseError(e.to_string()))?;

    let count = count_result.map(|r| r.count as i64).unwrap_or(0);

    Ok((count, max_per_day))
}
