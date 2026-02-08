use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::{broadcast, mpsc, oneshot, RwLock};

use crate::protocol::{ClientEvent, CommandResponse, Device, ServerMessage};
use crate::server::apns::ApnsClient;

pub type SharedState = Arc<AppState>;

pub struct DeviceConnection {
    pub device_id: String,
    pub name: String,
    pub authenticated: bool,
    pub tx: mpsc::UnboundedSender<ServerMessage>,
}

pub struct PendingPairing {
    pub device_id: String,
    pub name: String,
}

pub struct AppState {
    pub connections: RwLock<HashMap<String, DeviceConnection>>,
    pub devices: RwLock<HashMap<String, Device>>,
    pub pending_pairings: RwLock<HashMap<String, PendingPairing>>,
    pub pending_commands: RwLock<HashMap<String, oneshot::Sender<CommandResponse>>>,
    pub api_key: String,
    pub client_tx: broadcast::Sender<ClientEvent>,
    pub start_time: Instant,
    pub data_dir: PathBuf,
    pub apns: Option<ApnsClient>,
}

impl AppState {
    pub fn new(
        api_key: String,
        devices: HashMap<String, Device>,
        data_dir: PathBuf,
        apns: Option<ApnsClient>,
    ) -> Self {
        let (client_tx, _) = broadcast::channel(256);
        Self {
            connections: RwLock::new(HashMap::new()),
            devices: RwLock::new(devices),
            pending_pairings: RwLock::new(HashMap::new()),
            pending_commands: RwLock::new(HashMap::new()),
            api_key,
            client_tx,
            start_time: Instant::now(),
            data_dir,
            apns,
        }
    }
}
