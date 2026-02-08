mod alarm;
mod config_cmd;
mod devices;
mod locate;
mod notify;
mod pair;
mod sleep;
mod status;

pub use alarm::{alarm_start, alarm_stop};
pub use config_cmd::{set_config, show_config};
pub use devices::list_devices;
pub use locate::locate;
pub use notify::send_notification;
pub use pair::pair;
pub use sleep::{sleep_start, sleep_stop};
pub use status::server_status;

use crate::config::Config;

pub(crate) async fn api_request(
    method: reqwest::Method,
    path: &str,
    body: Option<serde_json::Value>,
) -> Result<serde_json::Value, String> {
    let config = Config::load()?;
    let url = format!("{}{}", config.server.url, path);
    let client = reqwest::Client::new();

    let mut req = client
        .request(method, &url)
        .header("Authorization", format!("Bearer {}", config.server.api_key));

    if let Some(body) = body {
        req = req.json(&body);
    }

    let resp = req.send().await.map_err(|e| format!("Request failed: {e}"))?;
    let status = resp.status();
    let text = resp
        .text()
        .await
        .map_err(|e| format!("Failed to read response: {e}"))?;

    if !status.is_success() {
        return Err(format!("Server error ({}): {}", status, text));
    }

    if text.is_empty() {
        return Ok(serde_json::Value::Null);
    }

    serde_json::from_str(&text).map_err(|e| format!("Failed to parse response: {e}"))
}
