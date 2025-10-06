use crate::error::AppError;

pub fn calculate_credits(model: &str, seconds: i32) -> Result<i64, AppError> {
    let cost = match (model, seconds) {
        ("sora-2", 4) => 100,
        ("sora-2", 8) => 150,
        ("sora-2", 12) => 200,
        ("sora-2-pro", 4) => 280,
        ("sora-2-pro", 8) => 450,
        ("sora-2-pro", 12) => 560,
        _ => {
            return Err(AppError::BadRequest(format!(
                "Invalid model/duration combination: {} {}s. Supported: 4s, 8s, 12s",
                model, seconds
            )))
        }
    };

    Ok(cost)
}

pub fn validate_video_params(model: &str, size: &str, seconds: i32) -> Result<(), AppError> {
    if !["sora-2", "sora-2-pro"].contains(&model) {
        return Err(AppError::BadRequest(format!("Invalid model: {}", model)));
    }

    if !["720x1280", "1280x720"].contains(&size) {
        return Err(AppError::BadRequest(format!("Invalid size: {}. Must be 720x1280 or 1280x720", size)));
    }

    if ![4, 8, 12].contains(&seconds) {
        return Err(AppError::BadRequest(format!("Invalid duration: {}s. Must be 4, 8, or 12 seconds", seconds)));
    }

    if model == "sora-2-pro" && size != "720x1280" && size != "1280x720" {
        return Err(AppError::BadRequest("sora-2-pro only supports 720x1280 or 1280x720".to_string()));
    }

    Ok(())
}

pub fn credits_to_usd(credits: i64) -> String {
    let usd = credits as f64 * 0.01;
    format!("${:.2}", usd)
}

pub const STARTER_PACK_CREDITS: i64 = 1000;
pub const STARTER_PACK_PRICE_USD: f64 = 9.99;
pub const WELCOME_CREDITS: i64 = 100;
