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
use std::net::IpAddr;
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tracing::{info, warn};

use crate::config::{self, Config};
use state::AppState;

fn is_localhost(bind: &str) -> bool {
    match bind.parse::<IpAddr>() {
        Ok(IpAddr::V4(v4)) => v4.is_loopback(),
        Ok(IpAddr::V6(v6)) => v6.is_loopback(),
        Err(_) => bind == "localhost",
    }
}

fn register_mdns(port: u16) -> Option<mdns_sd::ServiceDaemon> {
    let mdns = match mdns_sd::ServiceDaemon::new() {
        Ok(d) => d,
        Err(e) => {
            warn!("Failed to start mDNS daemon: {}", e);
            return None;
        }
    };

    let raw_host = hostname::get()
        .ok()
        .and_then(|h| h.into_string().ok())
        .unwrap_or_else(|| "unknown".into());
    // Strip `.local` suffix if present — mdns-sd adds its own `.local.`
    let host = raw_host
        .strip_suffix(".local")
        .unwrap_or(&raw_host);
    let instance_name = format!("omcli on {}", host);

    let service_type = "_omcli._tcp.local.";
    let properties = [
        ("path", "/ws/device"),
        ("version", env!("CARGO_PKG_VERSION")),
    ];

    // Use a distinct hostname to avoid conflicting with macOS mDNSResponder's
    // own A/AAAA records for this machine's hostname.
    let service_host = format!("omcli-{}.local.", host);
    let service_info = match mdns_sd::ServiceInfo::new(
        service_type,
        &instance_name,
        &service_host,
        "",
        port,
        &properties[..],
    ) {
        Ok(info) => info.enable_addr_auto(),
        Err(e) => {
            warn!("Failed to create mDNS service info: {}", e);
            return None;
        }
    };

    if let Err(e) = mdns.register(service_info) {
        warn!("Failed to register mDNS service: {}", e);
        return None;
    }

    info!("mDNS: registered as \"{}\" on port {}", instance_name, port);
    Some(mdns)
}

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

    // Register mDNS service if not binding to localhost
    let mdns = if is_localhost(&bind) {
        info!("Binding to localhost — skipping mDNS registration");
        None
    } else {
        register_mdns(port)
    };

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .expect("Failed to bind address");

    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            tokio::signal::ctrl_c()
                .await
                .expect("Failed to listen for ctrl+c");
            info!("Shutting down...");
        })
        .await
        .expect("Server error");

    // Unregister mDNS on shutdown
    if let Some(mdns) = mdns {
        info!("Unregistering mDNS service...");
        let _ = mdns.shutdown();
    }
}
