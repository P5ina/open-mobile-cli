# omcli Reference

## Server commands

### omcli serve

Start the WebSocket relay server.

```
omcli serve
omcli serve --port 7333 --bind 0.0.0.0
omcli serve --bind 0.0.0.0 --host my.vps.com
omcli serve --bind 0.0.0.0 --no-qr
```

| Flag | Default | Description |
|------|---------|-------------|
| `--port` | `7333` | Server port |
| `--bind` | `127.0.0.1` | Bind address (`0.0.0.0` for LAN/remote) |
| `--host` | auto-detected | Override host in QR code (for VPS/Tailscale) |
| `--no-qr` | `false` | Suppress QR code output (Docker/headless) |

On startup the server prints: version, listen address, API key, QR code (unless `--no-qr`).

### omcli relay

Start the push notification relay server. Proxies APNs requests for self-hosted instances without Apple Developer keys.

```
omcli relay
omcli relay --port 7334 --bind 0.0.0.0
```

| Flag | Default | Description |
|------|---------|-------------|
| `--port` | from config or `7334` | Relay port |
| `--bind` | from config or `127.0.0.1` | Bind address |

Requires `[relay]` section in `config.toml` with APNs keys.

## REST API

### Authentication

All endpoints require `Authorization: Bearer <api_key>` header.

### Endpoints

#### POST /api/command

Send a command to a device.

**Request:**
```json
{
  "command": "alarm.start",
  "params": {"sound": "loud", "message": "Wake up"},
  "device_id": "optional-device-id"
}
```

**Response (success):**
```json
{
  "id": "uuid",
  "status": "ok",
  "data": null
}
```

**Response (error):**
```json
{
  "id": "uuid",
  "status": "error",
  "error": "Error description",
  "error_code": "USER_DECLINED"
}
```

#### GET /api/status

```json
{
  "version": "0.2.0",
  "uptime_secs": 3600,
  "devices_online": 1,
  "devices_total": 2
}
```

#### GET /api/devices

```json
[
  {
    "id": "device-uuid",
    "name": "iPhone",
    "online": true,
    "paired_at": 1700000000
  }
]
```

#### POST /api/devices/pair

**Request:**
```json
{"code": "123456"}
```

**Response:**
```json
{
  "device_id": "device-uuid",
  "name": "iPhone"
}
```

### Relay endpoints

- `POST /relay/push` — send a visible push notification
- `POST /relay/voip` — send a VoIP push (bypasses Do Not Disturb)
- `GET /relay/health` — health check

## Protocol commands

All commands are sent via `POST /api/command`. The `device_id` field is optional when only one device is paired.

| Command | Params | CLI | Notes |
|---------|--------|-----|-------|
| `alarm.start` | `sound` (`default`/`loud`/`hell`), `message?` | `omcli alarm start` | Falls back to APNs if offline |
| `alarm.stop` | — | `omcli alarm stop` | Falls back to APNs if offline |
| `notify.send` | `title?`, `body`, `priority?` | `omcli notify` | |
| `location.get` | `accuracy?` (`coarse`/`fine`) | `omcli locate` | Requires live WebSocket |
| `camera.snap` | `facing` (`front`/`back`) | `omcli camera snap` | Requires live WebSocket |
| `sleep.start` | — | `omcli sleep` | |
| `sleep.stop` | — | `omcli wake` | |
| `tts.speak` | `text`, `voice?` | — | No CLI wrapper |
| `device.status` | — | — | Returns battery, charging state |

## Error codes

Returned in the `error_code` field of command responses.

| Code | Description |
|------|-------------|
| `USER_DECLINED` | User cancelled the action on device (e.g. camera snap) |
| `PERMISSION_DENIED` | App lacks required permission (camera, location) |
| `CAMERA_ERROR` | Camera hardware/software error |
| `LOCATION_ERROR` | Location services error |
| `UNKNOWN_COMMAND` | Command not recognized by the device |
| `INTERNAL_ERROR` | Unexpected error on device |

## CLI output

| Command | Success output | Error output |
|---------|---------------|--------------|
| `alarm start` | `Alarm started` | JSON or error message |
| `alarm stop` | `Alarm stopped` | JSON or error message |
| `notify` | `Notification sent` | Error message |
| `locate` | Lat, lon, accuracy text | Error message |
| `camera snap` | `Saved <path> (<size> bytes)` | `The photo was declined on the device.` or error |
| `sleep` | `Sleep mode activated — screen will stay on` | JSON or error message |
| `wake` | `Sleep mode deactivated` | JSON or error message |
| `status` | Version, uptime, device counts | Error message |
| `devices` | Device list with online/offline | Error message |
| `pair` | Device ID and name | Error message |

## Configuration

### config.toml

```toml
[server]
url = "http://127.0.0.1:7333"   # CLI target server
api_key = "auto-generated-uuid"  # Bearer token
port = 7333                      # serve port
bind = "127.0.0.1"              # serve bind address
# relay_url = "https://relay.example.com"

# Direct APNs (requires Apple Developer account)
[apns]
key_path = "AuthKey.p8"         # relative to config dir, or absolute
key_id = "XXXXXXXXXX"
team_id = "XXXXXXXXXX"
bundle_id = "com.example.omcli"
# sandbox = false               # true for dev builds

# Relay server mode
[relay]
apns_key_path = "/data/AuthKey.p8"
apns_key_id = "XXXXXXXXXX"
apns_team_id = "XXXXXXXXXX"
apns_bundle_id = "com.example.omcli"
# max_requests_per_device_per_hour = 60
```

### Config locations

1. `$OMCLI_DATA_DIR/config.toml` (Docker: `/data/config.toml`)
2. `~/.omcli/config.toml`

Paired devices stored in `devices.json` next to `config.toml`.

## Docker

```bash
# Server
docker run -d -p 7333:7333 -v ./data:/data p5ina/omcli

# Relay
docker run -d -p 7334:7334 -v ./data:/data p5ina/omcli relay --bind 0.0.0.0 --port 7334

# Docker Compose
docker compose up -d serve    # server
docker compose up -d relay    # relay
```

## Push notification fallback order

1. **Local APNs** — if `[apns]` configured, send directly to Apple
2. **Relay** — if `relay_url` set, proxy through relay server
3. **Error** — no push method available
