use axum::{extract::State, http::StatusCode, Json};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::info;

use super::RelayState;

fn is_valid_device_token(token: &str) -> bool {
    token.len() == 64 && token.chars().all(|c| c.is_ascii_hexdigit())
}

fn default_sound() -> String {
    "default".to_string()
}

#[derive(Deserialize)]
pub struct PushRequest {
    pub device_token: String,
    pub title: String,
    pub body: String,
    #[serde(default = "default_sound")]
    pub sound: String,
}

#[derive(Deserialize)]
pub struct VoipRequest {
    pub voip_token: String,
    #[serde(rename = "type")]
    pub push_type: String,
    #[serde(default)]
    pub sound: Option<String>,
    #[serde(default)]
    pub message: Option<String>,
}

#[derive(Serialize)]
pub struct RelayResponse {
    status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

pub async fn push_handler(
    State(state): State<Arc<RelayState>>,
    Json(req): Json<PushRequest>,
) -> Result<Json<RelayResponse>, (StatusCode, Json<RelayResponse>)> {
    if !is_valid_device_token(&req.device_token) {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(RelayResponse {
                status: "error".into(),
                error: Some("Invalid device token: must be 64 hex characters".into()),
            }),
        ));
    }

    if !state.rate_limiter.check(&req.device_token) {
        return Err((
            StatusCode::TOO_MANY_REQUESTS,
            Json(RelayResponse {
                status: "error".into(),
                error: Some("Rate limit exceeded".into()),
            }),
        ));
    }

    let params = serde_json::json!({
        "title": req.title,
        "body": req.body,
        "sound": req.sound,
    });

    info!("Relay push to {}...", &req.device_token[..8]);

    state
        .apns
        .send_notify_push(&req.device_token, &params)
        .await
        .map_err(|e| {
            (
                StatusCode::BAD_GATEWAY,
                Json(RelayResponse {
                    status: "error".into(),
                    error: Some(e),
                }),
            )
        })?;

    Ok(Json(RelayResponse {
        status: "ok".into(),
        error: None,
    }))
}

pub async fn voip_handler(
    State(state): State<Arc<RelayState>>,
    Json(req): Json<VoipRequest>,
) -> Result<Json<RelayResponse>, (StatusCode, Json<RelayResponse>)> {
    if !is_valid_device_token(&req.voip_token) {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(RelayResponse {
                status: "error".into(),
                error: Some("Invalid VoIP token: must be 64 hex characters".into()),
            }),
        ));
    }

    if !state.rate_limiter.check(&req.voip_token) {
        return Err((
            StatusCode::TOO_MANY_REQUESTS,
            Json(RelayResponse {
                status: "error".into(),
                error: Some("Rate limit exceeded".into()),
            }),
        ));
    }

    let params = serde_json::json!({
        "sound": req.sound,
        "message": req.message,
    });

    info!("Relay VoIP push to {}...", &req.voip_token[..8]);

    state
        .apns
        .send_voip_push(&req.voip_token, &req.push_type, &params)
        .await
        .map_err(|e| {
            (
                StatusCode::BAD_GATEWAY,
                Json(RelayResponse {
                    status: "error".into(),
                    error: Some(e),
                }),
            )
        })?;

    Ok(Json(RelayResponse {
        status: "ok".into(),
        error: None,
    }))
}

pub async fn health_handler() -> Json<serde_json::Value> {
    Json(serde_json::json!({"status": "ok"}))
}
