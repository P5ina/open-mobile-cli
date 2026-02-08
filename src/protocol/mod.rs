use serde::{Deserialize, Serialize};

// --- WebSocket messages ---

/// Messages from device to server over WebSocket
#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum DeviceMessage {
    #[serde(rename = "hello")]
    Hello { device_id: String, name: String },
    #[serde(rename = "auth")]
    Auth { device_id: String, token: String },
    #[serde(rename = "response")]
    Response {
        id: String,
        status: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        data: Option<serde_json::Value>,
        #[serde(skip_serializing_if = "Option::is_none")]
        error: Option<ErrorInfo>,
    },
    #[serde(rename = "event")]
    Event {
        event: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        data: Option<serde_json::Value>,
    },
    #[serde(rename = "push_token")]
    PushToken { token: String },
    #[serde(rename = "voip_token")]
    VoipToken { token: String },
}

/// Messages from server to device over WebSocket
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(tag = "type")]
pub enum ServerMessage {
    #[serde(rename = "pairing_code")]
    PairingCode { code: String },
    #[serde(rename = "auth_required")]
    AuthRequired,
    #[serde(rename = "auth_result")]
    AuthResult {
        success: bool,
        #[serde(skip_serializing_if = "Option::is_none")]
        token: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        error: Option<String>,
    },
    #[serde(rename = "command")]
    Command {
        id: String,
        command: String,
        params: serde_json::Value,
    },
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ErrorInfo {
    pub code: String,
    pub message: String,
}

// --- REST API types ---

/// POST /api/command body
#[derive(Debug, Serialize, Deserialize)]
pub struct CommandRequest {
    pub command: String,
    #[serde(default)]
    pub params: serde_json::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_id: Option<String>,
}

/// Command response (REST + internal)
#[derive(Debug, Serialize, Deserialize)]
pub struct CommandResponse {
    pub id: String,
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_code: Option<String>,
}

/// Stored device
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Device {
    pub id: String,
    pub name: String,
    pub token: String,
    pub paired_at: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub push_token: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub voip_token: Option<String>,
}

/// GET /api/devices response item
#[derive(Debug, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub id: String,
    pub name: String,
    pub online: bool,
    pub paired_at: u64,
}

/// GET /api/status response
#[derive(Debug, Serialize, Deserialize)]
pub struct ServerStatus {
    pub version: String,
    pub uptime_secs: u64,
    pub devices_online: usize,
    pub devices_total: usize,
}

/// POST /api/devices/pair body
#[derive(Debug, Serialize, Deserialize)]
pub struct PairRequest {
    pub code: String,
}

/// POST /api/devices/pair response
#[derive(Debug, Serialize, Deserialize)]
pub struct PairResponse {
    pub device_id: String,
    pub name: String,
}

/// Events broadcast to CLI WS clients
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ClientEvent {
    pub event: String,
    pub device_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<serde_json::Value>,
}
