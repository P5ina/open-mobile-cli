# open-mobile-cli

Remote mobile control — CLI + backend + iOS app.  
Control your phone from anywhere.

## Components

| Component | Language | Description |
|-----------|----------|-------------|
| `backend/` | Go | WebSocket relay server |
| `cli/` | Go | Command-line client |
| `ios/` | Swift | iOS companion app |
| `protocol/` | — | Protocol specification |

## Quick Start

```bash
# Install CLI
go install github.com/P5ina/open-mobile-cli/cli/cmd/omcli@latest

# Start backend
go install github.com/P5ina/open-mobile-cli/backend/cmd/omcli-server@latest
omcli-server

# Pair your phone
omcli pair <code>

# Use it
omcli alarm start --sound loud
omcli alarm stop
omcli locate
omcli notify "Hello from CLI"
omcli tts "Wake up"
omcli camera snap
omcli status
```

## Commands (v1)

- **alarm** — start/stop alarm with configurable sound level
- **notify** — send push notification
- **tts** — text-to-speech on device
- **location** — get device coordinates
- **camera** — take photo
- **status** — battery, charging, silent mode

## Architecture

See [ARCHITECTURE.md](docs/ARCHITECTURE.md)

## License

MIT
