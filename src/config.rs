use serde::{Deserialize, Serialize};
use std::path::PathBuf;

use crate::protocol::Device;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Config {
    pub server: ServerConfig,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub apns: Option<ApnsConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub relay: Option<RelayConfig>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ApnsConfig {
    pub key_path: String,
    pub key_id: String,
    pub team_id: String,
    pub bundle_id: String,
    #[serde(default)]
    pub sandbox: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ServerConfig {
    pub url: String,
    pub api_key: String,
    #[serde(default = "default_port")]
    pub port: u16,
    #[serde(default = "default_bind")]
    pub bind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub relay_url: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct RelayConfig {
    #[serde(default = "default_relay_port")]
    pub port: u16,
    #[serde(default = "default_bind")]
    pub bind: String,
    pub apns_key_path: String,
    pub apns_key_id: String,
    pub apns_team_id: String,
    pub apns_bundle_id: String,
    #[serde(default)]
    pub apns_sandbox: bool,
    #[serde(default = "default_max_requests")]
    pub max_requests_per_device_per_hour: u32,
}

impl RelayConfig {
    pub fn to_apns_config(&self) -> ApnsConfig {
        ApnsConfig {
            key_path: self.apns_key_path.clone(),
            key_id: self.apns_key_id.clone(),
            team_id: self.apns_team_id.clone(),
            bundle_id: self.apns_bundle_id.clone(),
            sandbox: self.apns_sandbox,
        }
    }
}

fn default_port() -> u16 {
    7333
}

fn default_bind() -> String {
    "127.0.0.1".to_string()
}

fn default_relay_port() -> u16 {
    7334
}

fn default_max_requests() -> u32 {
    60
}

impl Config {
    pub fn data_dir() -> PathBuf {
        if let Ok(dir) = std::env::var("OMCLI_DATA_DIR") {
            return PathBuf::from(dir);
        }
        dirs::home_dir()
            .expect("cannot determine home directory")
            .join(".omcli")
    }

    pub fn config_path() -> PathBuf {
        Self::data_dir().join("config.toml")
    }

    pub fn devices_path() -> PathBuf {
        Self::data_dir().join("devices.json")
    }

    pub fn load() -> Result<Self, String> {
        let path = Self::config_path();
        if !path.exists() {
            return Err(format!(
                "Config not found at {}. Run 'omcli serve' first.",
                path.display()
            ));
        }
        let content =
            std::fs::read_to_string(&path).map_err(|e| format!("Failed to read config: {e}"))?;
        toml::from_str(&content).map_err(|e| format!("Failed to parse config: {e}"))
    }

    pub fn save(&self) -> Result<(), String> {
        let dir = Self::data_dir();
        std::fs::create_dir_all(&dir)
            .map_err(|e| format!("Failed to create config dir: {e}"))?;
        let content =
            toml::to_string_pretty(self).map_err(|e| format!("Failed to serialize config: {e}"))?;
        std::fs::write(Self::config_path(), content)
            .map_err(|e| format!("Failed to write config: {e}"))?;
        Ok(())
    }

    /// Load existing config or create a new one with generated API key.
    pub fn load_or_create(port: u16, bind: &str) -> Self {
        let path = Self::config_path();
        if path.exists() {
            if let Ok(mut config) = Self::load() {
                // Update server address to match current serve params
                config.server.url = format!("http://{}:{}", bind, port);
                config.server.port = port;
                config.server.bind = bind.to_string();
                let _ = config.save();
                return config;
            }
        }
        let api_key = uuid::Uuid::new_v4().to_string();
        let config = Config {
            server: ServerConfig {
                url: format!("http://{}:{}", bind, port),
                api_key,
                port,
                bind: bind.to_string(),
                relay_url: None,
            },
            apns: None,
            relay: None,
        };
        config.save().expect("Failed to save initial config");
        config
    }
}

// --- Device persistence ---

pub fn load_devices() -> Vec<Device> {
    let path = Config::devices_path();
    if !path.exists() {
        return Vec::new();
    }
    let content = match std::fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };
    serde_json::from_str(&content).unwrap_or_default()
}

pub fn save_devices(devices: &[Device]) -> Result<(), String> {
    let dir = Config::data_dir();
    std::fs::create_dir_all(&dir).map_err(|e| format!("Failed to create data dir: {e}"))?;
    let content =
        serde_json::to_string_pretty(devices).map_err(|e| format!("Failed to serialize: {e}"))?;
    std::fs::write(Config::devices_path(), content)
        .map_err(|e| format!("Failed to write devices: {e}"))?;
    Ok(())
}
