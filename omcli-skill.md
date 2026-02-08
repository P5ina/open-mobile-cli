name: omcli
description: Control Timur's iPhone remotely — alarm, camera, notifications, location, sleep mode, status.

## Setup

Server runs on Raspberry Pi via systemd, port 7333.
Tailscale IP: 100.108.168.112
Config: ~/.omcli/config.toml

The iPhone app connects to the server over WebSocket. If one device is paired, `--device` is optional for all commands.
The app stores pairing tokens per server URL, so switching between servers (e.g. local vs Tailscale) doesn't require re-pairing.

## Commands

### Alarm

Start an alarm on the phone. The phone will play a looping siren sound until stopped.

```
omcli alarm start                              # default volume
omcli alarm start --sound loud                 # max volume
omcli alarm start --sound hell                 # max volume + continuous vibration
omcli alarm start --sound loud --message "Wake up!"
omcli alarm stop
```

Sound levels: `default` (70%), `loud` (100%), `hell` (100% + vibration loop).

If the app is in background with sleep mode on, the alarm triggers immediately via WebSocket.
If the app is killed, the server falls back to APNs push notification (limited — no looping audio).

### Sleep mode

Keeps the phone screen on and WebSocket alive so alarms work reliably. Use this before going to bed.

```
omcli sleep          # activate sleep mode — screen stays on, shows clock
omcli wake           # deactivate sleep mode
```

Sleep mode persists across app restarts. The phone shows a dark clock screen with "Alarm standby".
When an alarm fires during sleep mode, the full-screen alarm overlay takes over.

Always run `omcli sleep` before relying on alarm. Without it, iOS may kill the app and alarms won't loop.

### Camera

Take a photo using the phone's camera. Requires a live WebSocket connection (will not work via APNs).

```
omcli camera snap                              # back camera, auto filename (photo_YYYY-MM-DD_HH-MM-SS.jpg)
omcli camera snap --facing front               # selfie camera
omcli camera snap --facing back --output pic.jpg  # specific output path
```

When a snap command is sent, the phone shows a full-screen camera preview with a live viewfinder. The user must tap the shutter button to take the photo, or tap Cancel to decline. If declined, the CLI shows "The photo was declined on the device." The server has a 30-second timeout for the user to respond.

The phone must have the app open (or in background with active WebSocket). If the device is offline, you'll get an error instead of a silent push notification.

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
omcli config set server <url>         # set server URL
omcli config set api_key <key>        # set API key
omcli config set port <port>          # set server port
omcli config set apns.key_path <path> # APNs .p8 key file path
omcli config set apns.key_id <id>     # APNs key ID
omcli config set apns.team_id <id>    # Apple team ID
omcli config set apns.bundle_id <id>  # App bundle ID
omcli config set apns.sandbox true    # Use sandbox APNs (for dev)
```

## Common patterns

**Wake someone up reliably:**
```
omcli sleep                                    # do this before they go to bed
omcli alarm start --sound hell --message "WAKE UP"
```

**Check if phone is reachable:**
```
omcli status
```
Look at "Devices online" — if 0, the app is not connected.

**Gentle nudge:**
```
omcli notify "Hey, check your phone" --priority critical
```

## Troubleshooting

- "No devices connected" — the iOS app is not running or not connected. Open the app on the phone.
- "Device is not connected" — commands like `camera snap` need a live WebSocket. Open the app.
- "Device not connected and APNs not configured" — set up APNs config for offline fallback (alarm/sleep only).
- Alarm doesn't loop when app is killed — this is an iOS limitation. Use `omcli sleep` before bed.
- `--device` flag is needed only when multiple devices are paired.
- If the app lost its token (reinstall, etc.), it auto-recovers by requesting a new pairing code.

## Protocol commands (not exposed as CLI yet)

These work via the REST API (`POST /api/command`) but have no CLI wrapper:

- `tts.speak` — text-to-speech: `{"command": "tts.speak", "params": {"text": "Hello", "voice": "optional"}}`
- `device.status` — battery, charging state: `{"command": "device.status", "params": {}}`
