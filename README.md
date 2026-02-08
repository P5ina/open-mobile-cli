# omcli

Remote mobile device control from the command line. Single Rust binary — server, CLI, and push relay in one.

```
┌──────────┐    HTTP     ┌──────────────┐    WebSocket    ┌──────────┐
│  omcli   │ ─────────→  │ omcli serve  │ ←────────────── │ iOS App  │
│  (CLI)   │             │   (server)   │                 │          │
└──────────┘             └──────────────┘                 └──────────┘
                               ↑
                          REST API for
                          scripts & integrations
```

## Quick Start

**From binary:**

```bash
# Download from GitHub Releases
curl -L https://github.com/P5ina/open-mobile-cli/releases/latest/download/omcli-linux-amd64.tar.gz | tar xz
sudo mv omcli /usr/local/bin/
```

**From source:**

```bash
git clone https://github.com/P5ina/open-mobile-cli.git
cd open-mobile-cli
cargo install --path .
```

**Docker:**

```bash
docker run -d -p 7333:7333 -v ./data:/data p5ina/omcli
```

## Usage

```bash
# Start server
omcli serve
omcli serve --bind 0.0.0.0 --port 7333

# Pair device (open iOS app, get 6-digit code)
omcli pair 123456

# Alarm
omcli alarm start --sound loud --message "Wake up"
omcli alarm stop

# Notifications
omcli notify "Hello from terminal"

# Other commands
omcli locate                          # GPS coordinates
omcli camera snap --facing front      # take photo
omcli sleep                           # standby mode
omcli wake                            # exit standby
omcli status                          # server & device info
omcli devices                         # list paired devices
```

## Commands

| Command | Description |
|---------|-------------|
| `alarm start/stop` | Trigger alarm with sound level (`default`, `loud`, `hell`) |
| `notify` | Send push notification with priority |
| `locate` | Get device GPS coordinates |
| `camera snap` | Take photo (front/back camera) |
| `sleep` / `wake` | Standby mode (keeps screen on for alarm) |
| `status` | Server uptime, connected devices |
| `devices` | List paired devices |

## Self-Hosting with Docker

```yaml
# docker-compose.yml
services:
  serve:
    image: p5ina/omcli:latest
    ports:
      - "7333:7333"
    volumes:
      - ./data:/data
    environment:
      - RUST_LOG=info
    restart: unless-stopped
```

```bash
docker compose up -d serve
```

Config and paired devices are stored in the mounted `/data` volume.

### Push Relay

Self-hosted instances can send APNs push notifications through a relay server, no Apple Developer account needed:

```
self-hosted omcli  →  push relay  →  APNs  →  iPhone
```

```bash
# On relay server (with Apple Developer .p8 key)
docker compose up -d relay
```

Add `relay_url` to the self-hosted server config:

```toml
# data/config.toml
[server]
relay_url = "https://relay.example.com"
```

## Configuration

Config is stored at `~/.omcli/config.toml` (or `$OMCLI_DATA_DIR/config.toml` in Docker).

```toml
[server]
url = "http://127.0.0.1:7333"
api_key = "auto-generated-uuid"
port = 7333
bind = "127.0.0.1"
# relay_url = "https://relay.example.com"

# Optional: direct APNs (requires Apple Developer account)
# [apns]
# key_path = "AuthKey.p8"
# key_id = "XXXXXXXXXX"
# team_id = "XXXXXXXXXX"
# bundle_id = "com.example.omcli"

# Optional: relay server mode
# [relay]
# apns_key_path = "/data/AuthKey.p8"
# apns_key_id = "XXXXXXXXXX"
# apns_team_id = "XXXXXXXXXX"
# apns_bundle_id = "com.example.omcli"
```

## Architecture

| Component | Path | Description |
|-----------|------|-------------|
| Server | `src/server/` | axum WebSocket relay + REST API |
| CLI | `src/cli/` | HTTP client commands |
| Relay | `src/relay/` | APNs push proxy for self-hosted instances |
| Protocol | `src/protocol/` | Shared types and message definitions |
| iOS App | `ios/` | SwiftUI companion app |

**How it works:**

1. `omcli serve` starts a WebSocket relay server
2. iOS app connects via WebSocket, pairs with a 6-digit code
3. CLI sends commands via REST API, server relays to device via WebSocket
4. If device is offline, falls back to APNs push (direct or via relay)

## Platforms

| Platform | Download |
|----------|----------|
| Linux x86_64 | `omcli-linux-amd64.tar.gz` |
| Linux ARM64 | `omcli-linux-arm64.tar.gz` |
| macOS Apple Silicon | `omcli-macos-arm64.tar.gz` |
| Docker | `docker pull p5ina/omcli` |

## License

[MIT](LICENSE)
