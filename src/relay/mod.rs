mod api;
mod rate_limit;

use axum::routing::{get, post};
use axum::Router;
use std::sync::Arc;
use tracing::info;

use crate::config::Config;
use crate::server::apns::ApnsClient;
use rate_limit::RateLimiter;

pub struct RelayState {
    pub apns: ApnsClient,
    pub rate_limiter: RateLimiter,
}

pub async fn relay(port: Option<u16>, bind: Option<String>) {
    tracing_subscriber::fmt::init();

    let config = Config::load().expect("Failed to load config. Run 'omcli serve' first.");
    let relay_config = config
        .relay
        .expect("Missing [relay] section in config.toml");

    let port = port.unwrap_or(relay_config.port);
    let bind = bind.unwrap_or_else(|| relay_config.bind.clone());

    let apns_config = relay_config.to_apns_config();
    let apns =
        ApnsClient::new(&apns_config).expect("Failed to initialize APNs client for relay");

    let state = Arc::new(RelayState {
        apns,
        rate_limiter: RateLimiter::new(relay_config.max_requests_per_device_per_hour),
    });

    let app = Router::new()
        .route("/relay/push", post(api::push_handler))
        .route("/relay/voip", post(api::voip_handler))
        .route("/relay/health", get(api::health_handler))
        .with_state(state);

    let addr = format!("{}:{}", bind, port);
    println!("omcli relay v{}", env!("CARGO_PKG_VERSION"));
    println!("Listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .expect("Failed to bind address");

    info!("Push relay started on {}", addr);

    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            tokio::signal::ctrl_c()
                .await
                .expect("Failed to listen for ctrl+c");
            info!("Shutting down relay...");
        })
        .await
        .expect("Relay server error");
}
