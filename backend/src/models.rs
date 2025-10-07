use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub apple_user_id: String,
    pub email: Option<String>,
    pub credits_balance: i64,
    pub total_videos_generated: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Video {
    pub id: String,
    pub user_id: String,
    pub openai_video_id: String,
    pub status: VideoStatus,
    pub model: String,
    pub prompt: String,
    pub size: String,
    pub seconds: i32,
    pub video_url: Option<String>,
    pub thumbnail_url: Option<String>,
    pub spritesheet_url: Option<String>,
    pub download_url_expires_at: Option<DateTime<Utc>>,
    pub credits_cost: i64,
    pub progress: i32,
    pub created_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
    pub failed_at: Option<DateTime<Utc>>,
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum VideoStatus {
    Queued,
    #[serde(rename = "in_progress")]
    InProgress,
    Completed,
    Failed,
}

impl std::fmt::Display for VideoStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            VideoStatus::Queued => write!(f, "queued"),
            VideoStatus::InProgress => write!(f, "in_progress"),
            VideoStatus::Completed => write!(f, "completed"),
            VideoStatus::Failed => write!(f, "failed"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreditTransaction {
    pub id: String,
    pub user_id: String,
    pub amount: i64,
    pub balance_after: i64,
    pub transaction_type: String,
    pub description: String,
    pub video_id: Option<String>,
    pub revenuecat_transaction_id: Option<String>,
    pub metadata: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct AppleTokenRequest {
    pub identity_token: String,
}

#[derive(Debug, Serialize)]
pub struct AuthResponse {
    #[serde(rename = "user_id")]
    pub user_id: String,
    #[serde(rename = "credits_balance")]
    pub credits_balance: i64,
    pub created: bool,
}

#[derive(Debug, Deserialize)]
pub struct CreateVideoRequest {
    pub model: String,
    pub prompt: String,
    pub size: String,
    pub seconds: i32,
}

#[derive(Debug, Deserialize)]
pub struct EstimateRequest {
    pub model: String,
    pub size: String,
    pub seconds: i32,
}

#[derive(Debug, Serialize)]
pub struct EstimateResponse {
    pub credits_cost: i64,
    pub usd_equivalent: String,
    pub current_balance: i64,
    pub sufficient_credits: bool,
}

#[derive(Debug, Serialize)]
pub struct CreateVideoResponse {
    pub id: String,
    pub status: VideoStatus,
    pub credits_cost: i64,
    pub new_balance: i64,
    pub estimated_wait_seconds: i32,
}

#[derive(Debug, Serialize)]
pub struct BalanceResponse {
    pub credits_balance: i64,
    pub usd_equivalent: String,
}

#[derive(Debug, Serialize)]
pub struct VideoListResponse {
    pub videos: Vec<Video>,
    pub has_more: bool,
    pub total_count: i64,
}

#[derive(Debug, Deserialize)]
pub struct RevenueCatValidateRequest {
    pub transaction_id: String,
    pub product_id: String,
    #[allow(dead_code)]
    pub receipt_data: String,
}

#[derive(Debug, Serialize)]
pub struct RevenueCatValidateResponse {
    pub success: bool,
    pub credits_added: i64,
    pub new_balance: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct OpenAIWebhookEvent {
    pub id: String,
    pub object: String,
    pub created_at: i64,
    #[serde(rename = "type")]
    pub event_type: String,
    pub data: OpenAIWebhookData,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct OpenAIWebhookData {
    pub id: String,
}

#[derive(Debug, Deserialize)]
pub struct OpenAIVideoResponse {
    pub id: String,
    #[allow(dead_code)]
    pub object: String,
    #[allow(dead_code)]
    pub created_at: i64,
    pub status: String,
    #[allow(dead_code)]
    pub model: String,
    pub progress: Option<i32>,
    #[allow(dead_code)]
    pub seconds: Option<String>,
    #[allow(dead_code)]
    pub size: Option<String>,
    pub error: Option<OpenAIError>,
}

#[derive(Debug, Deserialize)]
pub struct OpenAIError {
    #[allow(dead_code)]
    pub code: String,
    pub message: String,
}

impl User {
    pub fn new(apple_user_id: String, email: Option<String>) -> Self {
        let now = Utc::now();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            apple_user_id,
            email,
            credits_balance: 0,
            total_videos_generated: 0,
            created_at: now,
            updated_at: now,
        }
    }
}

impl Video {
    pub fn new(
        user_id: String,
        openai_video_id: String,
        model: String,
        prompt: String,
        size: String,
        seconds: i32,
        credits_cost: i64,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            user_id,
            openai_video_id,
            status: VideoStatus::Queued,
            model,
            prompt,
            size,
            seconds,
            video_url: None,
            thumbnail_url: None,
            spritesheet_url: None,
            download_url_expires_at: None,
            credits_cost,
            progress: 0,
            created_at: Utc::now(),
            completed_at: None,
            failed_at: None,
            error_message: None,
        }
    }
}
