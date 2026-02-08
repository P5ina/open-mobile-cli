mod api;
mod auth;
pub mod state;
mod ws_client;
mod ws_device;

use axum::{
    middleware,
    routing::{delete, get, post},
    Router,
};
use std::collections::HashMap;
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tracing::info;

use crate::config::{self, Config};
use state::AppState;

pub async fn serve(port: u16, bind: String) {
    tracing_subscriber::fmt::init();

    let config = Config::load_or_create(port, &bind);

    // Load saved devices
    let saved = config::load_devices();
    let devices: HashMap<String, _> = saved.into_iter().map(|d| (d.id.clone(), d)).collect();

    info!(
        "Loaded {} saved device(s)",
        devices.len()
    );

    let state = Arc::new(AppState::new(
        config.server.api_key.clone(),
        devices,
        Config::data_dir(),
    ));

    // Authenticated REST routes
    let api_routes = Router::new()
        .route("/api/command", post(api::post_command))
        .route("/api/status", get(api::get_status))
        .route("/api/devices", get(api::get_devices))
        .route("/api/devices/pair", post(api::pair_device))
        .route("/api/devices/{id}", delete(api::delete_device))
        .layer(middleware::from_fn_with_state(
            state.clone(),
            auth::auth_middleware,
        ));

    // WebSocket routes (auth handled inside handlers)
    let ws_routes = Router::new()
        .route("/ws/device", get(ws_device::ws_device_handler))
        .route("/ws/client", get(ws_client::ws_client_handler));

    let app = Router::new()
        .merge(api_routes)
        .merge(ws_routes)
        .layer(CorsLayer::permissive())
        .with_state(state);

    let addr = format!("{}:{}", bind, port);
    println!("omcli server v{}", env!("CARGO_PKG_VERSION"));
    println!("Listening on {}", addr);
    println!("API key: {}", config.server.api_key);

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .expect("Failed to bind address");
    axum::serve(listener, app)
        .await
        .expect("Server error");
}
