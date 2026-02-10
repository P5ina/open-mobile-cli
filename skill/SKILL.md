---
name: omcli
description: Remote mobile device control from the command line — alarm, camera, notifications, location, sleep mode, status.
allowed-tools: Bash
---

## Overview

omcli is a single Rust binary that includes a WebSocket relay server, a CLI client, and an optional push notification relay. The iOS companion app connects to the server via WebSocket; CLI commands are sent over HTTP and relayed to the device in real-time.

## Setup

```bash
# Start server (default: 127.0.0.1:7333)
omcli serve
omcli serve --bind 0.0.0.0 --port 7333       # LAN-accessible, iOS app auto-discovers via mDNS
omcli serve --bind 0.0.0.0 --host my.vps.com  # custom host in QR code

# Point CLI at the server (only needed if server is remote)
omcli config set server http://HOST:7333
omcli config set api_key <key>                 # from server startup logs
```

Config: `~/.omcli/config.toml` (or `$OMCLI_DATA_DIR/config.toml` in Docker).

The iOS app connects to the server over WebSocket. If one device is paired, `--device` is optional for all commands. The app stores pairing tokens per server URL, so switching between servers doesn't require re-pairing.

## Commands

### Pair

Pair a device using the 6-digit code shown in the iOS app.

```
omcli pair 123456
```

### Alarm

Start an alarm on the phone. The phone plays a looping siren sound until stopped.

```
omcli alarm start                              # default volume (70%)
omcli alarm start --sound loud                 # max volume (100%)
omcli alarm start --sound hell                 # max volume + continuous vibration
omcli alarm start --sound loud --message "Wake up!"
omcli alarm stop
```

Sound levels: `default` (70%), `loud` (100%), `hell` (100% + vibration loop).

If the app is in background with sleep mode on, the alarm triggers immediately via WebSocket.
If the app is killed, the server falls back to APNs push notification (limited — no looping audio).

### Sleep mode

Keeps the phone screen on and WebSocket alive so alarms work reliably.

```
omcli sleep                    # activate — screen stays on, shows clock
omcli wake                     # deactivate
```

Sleep mode persists across app restarts. The phone shows a dark clock screen with "Alarm standby". When an alarm fires during sleep mode, the full-screen alarm overlay takes over.

Always activate sleep mode before relying on alarm. Without it, iOS may kill the app and alarms won't loop.

### Camera

Take a photo using the phone's camera. Requires a live WebSocket connection (will not work via APNs).

```
omcli camera snap                              # back camera, auto filename (photo_YYYY-MM-DD_HH-MM-SS.jpg)
omcli camera snap --facing front               # selfie camera
omcli camera snap --facing back --output pic.jpg
```

The phone shows a full-screen camera preview. The user must tap the shutter button to take the photo, or tap Cancel to decline. If declined, the CLI shows "The photo was declined on the device." The server has a 30-second timeout.

### Notifications

Send a push notification to the phone.

```
omcli notify "Your text here"
omcli notify "Urgent message" --priority critical
omcli notify "Low priority" --priority low
```

Priority levels: `low` (passive), `normal` (default), `critical` (bypasses Do Not Disturb).

### Location

Get the phone's GPS coordinates.

```
omcli locate
```

Returns latitude, longitude, and accuracy in meters.

### Status

```
omcli status         # server uptime, version, connected devices count
omcli devices        # list all paired devices with online/offline status
```

### Config

```
omcli config                          # show current config
omcli config set server <url>         # server URL
omcli config set api_key <key>        # API key
omcli config set port <port>          # server port
omcli config set apns.key_path <path> # APNs .p8 key file path
omcli config set apns.key_id <id>     # APNs key ID
omcli config set apns.team_id <id>    # Apple team ID
omcli config set apns.bundle_id <id>  # app bundle ID
omcli config set apns.sandbox true    # use sandbox APNs (for dev builds)
```

## Common patterns

**Wake someone up reliably:**
```
omcli sleep
omcli alarm start --sound hell --message "WAKE UP"
```

**Check if phone is reachable:**
```
omcli status
```
Look at "Devices online" — if 0, the app is not connected.

**Quick notification:**
```
omcli notify "Hey, check your phone" --priority critical
```

## Protocol commands (not exposed as CLI yet)

These work via the REST API (`POST /api/command`) but have no CLI subcommand:

- `tts.speak` — text-to-speech: `{"command": "tts.speak", "params": {"text": "Hello", "voice": "optional"}}`
- `device.status` — battery level, charging state: `{"command": "device.status", "params": {}}`

## REST API

All commands go through `POST /api/command` with Bearer token auth:

```
curl -X POST http://HOST:7333/api/command \
  -H "Authorization: Bearer <api_key>" \
  -H "Content-Type: application/json" \
  -d '{"command": "alarm.start", "params": {"sound": "loud"}, "device_id": "optional"}'
```

Other endpoints:
- `GET /api/status` — server status
- `GET /api/devices` — list paired devices
- `POST /api/devices/pair` — pair device with `{"code": "123456"}`

## Troubleshooting

- "No devices connected" — the iOS app is not running or WebSocket is disconnected. Open the app.
- "Device is not connected" — commands like `camera snap` need a live WebSocket. Open the app.
- "Device not connected and APNs not configured" — set up APNs or relay for offline push fallback.
- Alarm doesn't loop when app is killed — iOS limitation. Use `omcli sleep` before bed.
- `--device` flag is needed only when multiple devices are paired.
- If the app lost its token (reinstall, etc.), it auto-recovers by requesting a new pairing code.
