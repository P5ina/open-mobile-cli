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

## Offline Push Notifications

When the iOS app is connected via WebSocket, commands are delivered instantly. When the app is in background or the phone is offline, omcli falls back to Apple Push Notifications (APNs) to wake the device.

There are two ways to configure push — choose based on whether you have an Apple Developer account.

### Option A: Direct APNs (you have an Apple Developer account)

The server sends pushes directly to Apple. No extra infrastructure needed.

```
omcli serve  →  APNs  →  iPhone
```

1. Get a `.p8` key from [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list) (Keys → Create)
2. Place the key file next to your config:

```bash
cp AuthKey_XXXXXXXXXX.p8 ~/.omcli/   # or /data/ in Docker
```

3. Add the `[apns]` section to `config.toml`:

```toml
[apns]
key_path = "AuthKey_XXXXXXXXXX.p8"   # relative to config dir, or absolute path
key_id = "XXXXXXXXXX"
team_id = "XXXXXXXXXX"
bundle_id = "com.example.omcli"
# sandbox = false                    # set to true for development builds
```

4. Restart the server. Done — pushes go directly to Apple.

### Option B: Push Relay (no Apple Developer account)

A relay is a public server (run by someone with a `.p8` key) that proxies push requests to APNs. Your self-hosted server sends HTTP requests to the relay instead of talking to Apple directly.

```
self-hosted omcli  →  push relay  →  APNs  →  iPhone
```

**On your server** — just set `relay_url`, no APNs keys needed:

```toml
# data/config.toml
[server]
relay_url = "https://relay.example.com"
```

**On the relay server** — requires the `.p8` key and a `[relay]` config section:

```toml
# data/config.toml
[relay]
apns_key_path = "/data/AuthKey_XXXXXXXXXX.p8"
apns_key_id = "XXXXXXXXXX"
apns_team_id = "XXXXXXXXXX"
apns_bundle_id = "com.example.omcli"
# max_requests_per_device_per_hour = 60
```

The relay exposes three endpoints:
- `POST /relay/push` — send a visible notification
- `POST /relay/voip` — send a VoIP push (bypasses Do Not Disturb)
- `GET /relay/health` — health check

### Push priority

When a device is offline, the server tries in order:

1. **Local APNs** — if `[apns]` is configured, send directly
2. **Relay** — if `relay_url` is set, proxy through relay
3. **Error** — no push method available

If both `[apns]` and `relay_url` are configured, direct APNs always takes priority.

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

  relay:
    image: p5ina/omcli:latest
    command: ["relay", "--bind", "0.0.0.0", "--port", "7334"]
    ports:
      - "7334:7334"
    volumes:
      - ./data:/data
    environment:
      - RUST_LOG=info
    restart: unless-stopped
```

```bash
# Deploy server
docker compose up -d serve

# Deploy relay (separate machine, or same machine if you need both)
docker compose up -d relay
```

Config, paired devices, and `.p8` keys are stored in the mounted `./data` volume.

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

## AI Agent Integration

The file [`omcli-skill.md`](omcli-skill.md) is a skill definition for AI agents (OpenClaw, Claude Code, etc.). Give it to your agent so it can control your phone with natural language:

> "Wake me up at 7am with a loud alarm"
> "Send a notification to my phone"
> "Take a photo with the front camera"

The skill file contains all commands, parameters, common patterns, and troubleshooting tips — everything an agent needs to use omcli autonomously.

## Platforms

| Platform | Download |
|----------|----------|
| Linux x86_64 | `omcli-linux-amd64.tar.gz` |
| Linux ARM64 | `omcli-linux-arm64.tar.gz` |
| macOS Apple Silicon | `omcli-macos-arm64.tar.gz` |
| Docker | `docker pull p5ina/omcli` |

## License

[MIT](LICENSE)
