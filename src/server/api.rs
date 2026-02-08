use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::oneshot;
use uuid::Uuid;

use crate::config;
use crate::protocol::*;
use crate::server::state::AppState;

pub async fn post_command(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CommandRequest>,
) -> Result<Json<CommandResponse>, (StatusCode, String)> {
    let connections = state.connections.read().await;

    // Find target device — check connected first
    let device_id = if let Some(id) = &req.device_id {
        id.clone()
    } else {
        // Try connected devices first
        let connected: Vec<_> = connections
            .iter()
            .filter(|(_, c)| c.authenticated)
            .collect();
        match connected.len() {
            0 => {
                // No connected devices — try to find a single paired device for APNs fallback
                let devices = state.devices.read().await;
                if devices.len() == 1 {
                    devices.keys().next().unwrap().clone()
                } else {
                    drop(devices);
                    drop(connections);
                    return Err((StatusCode::NOT_FOUND, "No devices connected".into()));
                }
            }
            1 => connected[0].0.clone(),
            _ => {
                return Err((
                    StatusCode::BAD_REQUEST,
                    "Multiple devices connected, specify --device".into(),
                ));
            }
        }
    };

    // Check if device is connected and authenticated
    let is_connected = connections
        .get(&device_id)
        .map(|c| c.authenticated)
        .unwrap_or(false);

    // If device is not connected, try APNs fallback for alarm commands
    if !is_connected {
        drop(connections);
        return try_apns_fallback(&state, &device_id, &req.command, &req.params).await;
    }

    let cmd_id = Uuid::new_v4().to_string();
    let server_msg = ServerMessage::Command {
        id: cmd_id.clone(),
        command: req.command,
        params: req.params,
    };

    // Create oneshot channel for response
    let (tx, rx) = oneshot::channel();
    drop(connections); // release read lock before write lock
    state
        .pending_commands
        .write()
        .await
        .insert(cmd_id.clone(), tx);

    // Send command to device
    {
        let connections = state.connections.read().await;
        if let Some(conn) = connections.get(&device_id) {
            conn.tx.send(server_msg).map_err(|_| {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to send to device".into(),
                )
            })?;
        }
    }

    // Wait for response with timeout (30s)
    match tokio::time::timeout(std::time::Duration::from_secs(30), rx).await {
        Ok(Ok(resp)) => Ok(Json(resp)),
        Ok(Err(_)) => {
            state.pending_commands.write().await.remove(&cmd_id);
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                "Response channel closed".into(),
            ))
        }
        Err(_) => {
            state.pending_commands.write().await.remove(&cmd_id);
            Err((
                StatusCode::GATEWAY_TIMEOUT,
                "Device did not respond in time".into(),
            ))
        }
    }
}

async fn try_apns_fallback(
    state: &Arc<AppState>,
    device_id: &str,
    command: &str,
    params: &serde_json::Value,
) -> Result<Json<CommandResponse>, (StatusCode, String)> {
    let apns = state.apns.as_ref().ok_or((
        StatusCode::NOT_FOUND,
        format!("Device {} not connected and APNs not configured", device_id),
    ))?;

    let devices = state.devices.read().await;
    let device = devices.get(device_id).ok_or((
        StatusCode::NOT_FOUND,
        format!("Device {} not found", device_id),
    ))?;

    let push_token = device.push_token.as_ref().ok_or((
        StatusCode::BAD_REQUEST,
        format!(
            "Device {} not connected and has no push token registered",
            device_id
        ),
    ))?;

    let push_token = push_token.clone();
    drop(devices);

    apns.send_alarm_push(&push_token, command, params)
        .await
        .map_err(|e| (StatusCode::BAD_GATEWAY, e))?;

    Ok(Json(CommandResponse {
        id: Uuid::new_v4().to_string(),
        status: "ok".into(),
        data: Some(serde_json::json!({"delivered_via": "apns"})),
        error: None,
    }))
}

pub async fn get_status(State(state): State<Arc<AppState>>) -> Json<ServerStatus> {
    let connections = state.connections.read().await;
    let devices = state.devices.read().await;
    let online = connections.iter().filter(|(_, c)| c.authenticated).count();
    Json(ServerStatus {
        version: env!("CARGO_PKG_VERSION").to_string(),
        uptime_secs: state.start_time.elapsed().as_secs(),
        devices_online: online,
        devices_total: devices.len(),
    })
}

pub async fn get_devices(State(state): State<Arc<AppState>>) -> Json<Vec<DeviceInfo>> {
    let devices = state.devices.read().await;
    let connections = state.connections.read().await;
    let list = devices
        .values()
        .map(|d| {
            let online = connections
                .get(&d.id)
                .map(|c| c.authenticated)
                .unwrap_or(false);
            DeviceInfo {
                id: d.id.clone(),
                name: d.name.clone(),
                online,
                paired_at: d.paired_at,
            }
        })
        .collect();
    Json(list)
}

pub async fn pair_device(
    State(state): State<Arc<AppState>>,
    Json(req): Json<PairRequest>,
) -> Result<Json<PairResponse>, (StatusCode, String)> {
    let pending = state.pending_pairings.write().await.remove(&req.code);
    let pending = pending.ok_or((StatusCode::NOT_FOUND, "Invalid pairing code".into()))?;

    let token = Uuid::new_v4().to_string();
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let device = Device {
        id: pending.device_id.clone(),
        name: pending.name.clone(),
        token: token.clone(),
        paired_at: now,
        push_token: None,
    };

    // Save device to state
    state
        .devices
        .write()
        .await
        .insert(device.id.clone(), device);

    // Persist to disk
    {
        let devices: Vec<_> = state.devices.read().await.values().cloned().collect();
        let _ = config::save_devices(&devices);
    }

    // Mark connection as authenticated and send token to device
    {
        let mut connections = state.connections.write().await;
        if let Some(conn) = connections.get_mut(&pending.device_id) {
            conn.authenticated = true;
            let _ = conn.tx.send(ServerMessage::AuthResult {
                success: true,
                token: Some(token),
                error: None,
            });
        }
    }

    // Broadcast event
    let _ = state.client_tx.send(ClientEvent {
        event: "device.paired".into(),
        device_id: pending.device_id.clone(),
        data: None,
    });

    Ok(Json(PairResponse {
        device_id: pending.device_id,
        name: pending.name,
    }))
}

pub async fn delete_device(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, String)> {
    let removed = state.devices.write().await.remove(&id);
    if removed.is_none() {
        return Err((StatusCode::NOT_FOUND, "Device not found".into()));
    }

    // Disconnect if connected
    state.connections.write().await.remove(&id);

    // Persist
    {
        let devices: Vec<_> = state.devices.read().await.values().cloned().collect();
        let _ = config::save_devices(&devices);
    }

    Ok(StatusCode::NO_CONTENT)
}
