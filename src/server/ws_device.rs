use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::IntoResponse,
};
use rand::Rng;
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::{info, warn};

use crate::config;
use crate::protocol::*;
use crate::server::state::{AppState, DeviceConnection, PendingPairing};

pub async fn ws_device_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_device_socket(socket, state))
}

async fn handle_device_socket(mut socket: WebSocket, state: Arc<AppState>) {
    // 1. Wait for Hello message
    let (device_id, name) = match socket.recv().await {
        Some(Ok(Message::Text(text))) => match serde_json::from_str::<DeviceMessage>(&text) {
            Ok(DeviceMessage::Hello { device_id, name }) => (device_id, name),
            _ => {
                warn!("Expected Hello message, got something else");
                return;
            }
        },
        _ => return,
    };

    info!("Device connected: {} ({})", name, device_id);

    // 2. Create mpsc channel for sending commands to this device
    let (tx, mut rx) = mpsc::unbounded_channel::<ServerMessage>();

    let conn = DeviceConnection {
        device_id: device_id.clone(),
        name: name.clone(),
        authenticated: false,
        tx: tx.clone(),
    };
    state
        .connections
        .write()
        .await
        .insert(device_id.clone(), conn);

    // 3. Check if device is already paired
    let is_paired = state.devices.read().await.contains_key(&device_id);

    if !is_paired {
        // Generate 6-digit pairing code
        let code = format!("{:06}", rand::thread_rng().gen_range(100_000..999_999u32));
        info!("Pairing code for {}: {}", device_id, code);

        state.pending_pairings.write().await.insert(
            code.clone(),
            PendingPairing {
                device_id: device_id.clone(),
                name: name.clone(),
            },
        );

        let msg = ServerMessage::PairingCode { code };
        let text = serde_json::to_string(&msg).unwrap();
        if socket.send(Message::Text(text.into())).await.is_err() {
            cleanup(&state, &device_id).await;
            return;
        }
    } else {
        // Device is already paired — tell it to authenticate
        let msg = ServerMessage::AuthRequired;
        let text = serde_json::to_string(&msg).unwrap();
        if socket.send(Message::Text(text.into())).await.is_err() {
            cleanup(&state, &device_id).await;
            return;
        }
    }

    // Broadcast connect event
    let _ = state.client_tx.send(ClientEvent {
        event: "device.connected".into(),
        device_id: device_id.clone(),
        data: None,
    });

    // 4. Main event loop
    loop {
        tokio::select! {
            // Messages from device
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        handle_device_message(&text, &device_id, &state).await;
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    Some(Err(e)) => {
                        warn!("WS error from {}: {}", device_id, e);
                        break;
                    }
                    _ => {}
                }
            }
            // Commands to send to device
            cmd = rx.recv() => {
                match cmd {
                    Some(msg) => {
                        let text = serde_json::to_string(&msg).unwrap();
                        if socket.send(Message::Text(text.into())).await.is_err() {
                            break;
                        }
                    }
                    None => break,
                }
            }
        }
    }

    info!("Device disconnected: {}", device_id);
    cleanup(&state, &device_id).await;
}

async fn handle_device_message(text: &str, device_id: &str, state: &Arc<AppState>) {
    let msg = match serde_json::from_str::<DeviceMessage>(text) {
        Ok(m) => m,
        Err(e) => {
            warn!("Failed to parse device message: {}", e);
            return;
        }
    };

    match msg {
        DeviceMessage::Auth {
            device_id: did,
            token,
        } => {
            let valid = {
                let devices = state.devices.read().await;
                devices
                    .get(&did)
                    .map(|d| d.token == token)
                    .unwrap_or(false)
            };

            let mut connections = state.connections.write().await;
            if let Some(conn) = connections.get_mut(&did) {
                if valid {
                    conn.authenticated = true;
                    info!("Device authenticated: {}", did);
                    let _ = conn.tx.send(ServerMessage::AuthResult {
                        success: true,
                        token: None,
                        error: None,
                    });
                } else {
                    warn!("Auth failed for {}, generating new pairing code", did);
                    drop(connections);

                    // Remove stale device entry
                    state.devices.write().await.remove(&did);
                    let devices_vec: Vec<_> =
                        state.devices.read().await.values().cloned().collect();
                    let _ = config::save_devices(&devices_vec);

                    // Generate new pairing code
                    let code =
                        format!("{:06}", rand::thread_rng().gen_range(100_000..999_999u32));
                    info!("Re-pairing code for {}: {}", did, code);
                    state.pending_pairings.write().await.insert(
                        code.clone(),
                        PendingPairing {
                            device_id: did.clone(),
                            name: state
                                .connections
                                .read()
                                .await
                                .get(&did)
                                .map(|c| c.name.clone())
                                .unwrap_or_default(),
                        },
                    );

                    let mut connections = state.connections.write().await;
                    if let Some(conn) = connections.get_mut(&did) {
                        let _ = conn.tx.send(ServerMessage::PairingCode { code });
                    }
                }
            }
        }
        DeviceMessage::Response {
            id,
            status,
            data,
            error,
        } => {
            let sender = state.pending_commands.write().await.remove(&id);
            if let Some(sender) = sender {
                let _ = sender.send(CommandResponse {
                    id,
                    status,
                    data,
                    error: error.map(|e| e.message),
                });
            }
        }
        DeviceMessage::Event { event, data } => {
            let _ = state.client_tx.send(ClientEvent {
                event,
                device_id: device_id.to_string(),
                data,
            });
        }
        DeviceMessage::PushToken { token } => {
            let mut devices = state.devices.write().await;
            if let Some(device) = devices.get_mut(device_id) {
                device.push_token = Some(token);
                info!("Stored push token for device {}", device_id);
                let devices_vec: Vec<_> = devices.values().cloned().collect();
                let _ = config::save_devices(&devices_vec);
            } else {
                warn!("Push token received from unknown device {}", device_id);
            }
        }
        DeviceMessage::Hello { .. } => {
            warn!("Unexpected Hello message from {}", device_id);
        }
    }
}

async fn cleanup(state: &Arc<AppState>, device_id: &str) {
    state.connections.write().await.remove(device_id);
    let _ = state.client_tx.send(ClientEvent {
        event: "device.disconnected".into(),
        device_id: device_id.to_string(),
        data: None,
    });
}
