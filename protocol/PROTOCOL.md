# Protocol Specification

## Transport

WebSocket (JSON messages over WS)

## Message Types

### Command (client → backend → device)
```json
{
  "id": "uuid-v4",
  "type": "command",
  "command": "alarm.start",
  "params": {
    "sound": "loud",
    "message": "Wake up!"
  }
}
```

### Response (device → backend → client)
```json
{
  "id": "uuid-v4",
  "type": "response",
  "status": "ok",
  "data": {}
}
```

### Error Response
```json
{
  "id": "uuid-v4",
  "type": "response",
  "status": "error",
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "Camera permission not granted"
  }
}
```

### Event (device → backend → client)
```json
{
  "type": "event",
  "event": "alarm.dismissed",
  "data": {
    "dismissedAt": "2026-02-08T09:00:00Z"
  }
}
```

## Authentication

### Pairing Flow

1. Device connects to backend WS, sends `device.hello` with device_id
2. Backend generates 6-digit pairing code, sends to device
3. Device displays code on screen
4. CLI sends `POST /api/pair` with code
5. Backend confirms pairing, issues device_token
6. All subsequent messages authenticated via device_token

### CLI Authentication

CLI stores server URL + API key in `~/.omcli/config.json`

## Commands

### alarm.start
```json
{ "sound": "default" | "loud" | "hell", "message": "string (optional)" }
```

### alarm.stop
```json
{}
```

### notify.send
```json
{ "title": "string", "body": "string", "sound": true, "priority": "low" | "normal" | "critical" }
```

### tts.speak
```json
{ "text": "string", "voice": "string (optional)" }
```

### location.get
```json
{ "accuracy": "coarse" | "precise" }
→ { "lat": 42.87, "lon": 74.59, "accuracy": 10.0, "timestamp": "ISO-8601" }
```

### camera.snap
```json
{ "facing": "front" | "back" }
→ { "base64": "...", "format": "jpeg" }
```

### device.status
```json
{}
→ { "battery": 85, "charging": true, "silentMode": false, "online": true }
```

## Events

| Event | Data | Description |
|-------|------|-------------|
| `alarm.dismissed` | `{ dismissedAt }` | User dismissed the alarm |
| `alarm.snoozed` | `{ snoozeUntil }` | User snoozed the alarm |
| `device.connected` | `{ deviceId }` | Device came online |
| `device.disconnected` | `{ deviceId }` | Device went offline |
