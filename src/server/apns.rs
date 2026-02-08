use a2::client::ClientConfig;
use a2::{
    Client, DefaultNotificationBuilder, Endpoint, NotificationBuilder, NotificationOptions,
    Priority, PushType,
};
use serde::Serialize;
use tracing::{info, warn};

use crate::config::ApnsConfig;

pub struct ApnsClient {
    client: Client,
    bundle_id: String,
}

#[derive(Serialize)]
struct AlarmPayload<'a> {
    command: &'a str,
    params: &'a serde_json::Value,
}

impl ApnsClient {
    pub fn new(config: &ApnsConfig) -> Result<Self, String> {
        let mut key_file = std::fs::File::open(&config.key_path)
            .map_err(|e| format!("Failed to open APNs key file '{}': {e}", config.key_path))?;

        let endpoint = if config.sandbox {
            Endpoint::Sandbox
        } else {
            Endpoint::Production
        };

        let client = Client::token(
            &mut key_file,
            &config.key_id,
            &config.team_id,
            ClientConfig::new(endpoint),
        )
        .map_err(|e| format!("Failed to create APNs client: {e}"))?;

        info!("APNs client initialized (sandbox={})", config.sandbox);

        Ok(Self {
            client,
            bundle_id: config.bundle_id.clone(),
        })
    }

    pub async fn send_alarm_push(
        &self,
        token: &str,
        command: &str,
        params: &serde_json::Value,
    ) -> Result<(), String> {
        let builder = DefaultNotificationBuilder::new()
            .set_body("Alarm triggered")
            .set_content_available()
            .set_category("alarm");

        let options = NotificationOptions {
            apns_topic: Some(&self.bundle_id),
            apns_push_type: Some(PushType::Alert),
            apns_priority: Some(Priority::High),
            ..Default::default()
        };

        let mut payload = builder.build(token, options);

        let custom = AlarmPayload { command, params };
        payload
            .add_custom_data("omcli", &custom)
            .map_err(|e| format!("Failed to build APNs payload: {e}"))?;

        match self.client.send(payload).await {
            Ok(response) => {
                info!("APNs push sent to {}: {:?}", &token[..8], response);
                Ok(())
            }
            Err(e) => {
                warn!("APNs push failed: {e}");
                Err(format!("APNs push failed: {e}"))
            }
        }
    }

    pub async fn send_voip_push(
        &self,
        token: &str,
        command: &str,
        params: &serde_json::Value,
    ) -> Result<(), String> {
        let voip_topic = format!("{}.voip", self.bundle_id);

        let builder = DefaultNotificationBuilder::new()
            .set_content_available();

        let options = NotificationOptions {
            apns_topic: Some(&voip_topic),
            apns_push_type: Some(PushType::Voip),
            apns_priority: Some(Priority::High),
            ..Default::default()
        };

        let mut payload = builder.build(token, options);

        let custom = AlarmPayload { command, params };
        payload
            .add_custom_data("omcli", &custom)
            .map_err(|e| format!("Failed to build VoIP payload: {e}"))?;

        match self.client.send(payload).await {
            Ok(response) => {
                info!("VoIP push sent to {}: {:?}", &token[..8], response);
                Ok(())
            }
            Err(e) => {
                warn!("VoIP push failed: {e}");
                Err(format!("VoIP push failed: {e}"))
            }
        }
    }
}
