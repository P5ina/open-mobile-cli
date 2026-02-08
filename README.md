# open-mobile-cli

Remote mobile control — CLI + backend + iOS app.  
Control your phone from anywhere.

## Components

| Component | Language | Description |
|-----------|----------|-------------|
| `src/server/` | Rust | WebSocket relay server (`omcli serve`) |
| `src/cli/` | Rust | CLI commands |
| `ios/` | Swift | iOS companion app |
| `protocol/` | — | Protocol specification |

Single binary — server and CLI in one:

```bash
cargo install open-mobile-cli
```

## Usage

```bash
# Start server
omcli serve
omcli serve --port 8080 --bind 0.0.0.0

# Pair device
omcli pair <code>

# Commands
omcli alarm start --sound loud
omcli alarm stop
omcli locate
omcli notify "Hello from CLI"
omcli tts "Wake up"
omcli camera snap --facing front
omcli status
omcli devices
```

## Commands

| Command | Description |
|---------|-------------|
| `alarm start/stop` | Trigger alarm with configurable sound level |
| `notify` | Send push notification |
| `tts` | Text-to-speech on device |
| `locate` | Get device GPS coordinates |
| `camera snap` | Take photo |
| `status` | Battery, charging, silent mode |

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Tech Stack

- **Rust** — axum, clap, tokio, sqlx + SQLite
- **Swift** — SwiftUI, URLSessionWebSocketTask

## License

MIT
