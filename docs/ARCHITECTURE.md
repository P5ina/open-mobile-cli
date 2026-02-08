# open-mobile-cli — Remote Mobile Control

Open-source CLI + backend + iOS app для удалённого управления телефоном.

## Компоненты

```
┌─────────────┐     HTTP/WS      ┌─────────────┐      WS (persistent)     ┌─────────────┐
│  omcli *    │ ──────────────→  │ omcli serve │  ←──────────────────────  │  iOS App    │
│  (CLI)      │                  │  (relay)    │                           │ OpenMobile  │
└─────────────┘                  └─────────────┘                           └─────────────┘
       один бинарник                    ↑
                                  HTTP API для
                                  интеграций
                                  (OpenClaw, скрипты, CI)
```

## Стек

- **Backend + CLI:** Rust (один бинарник, субкоманды)
  - `axum` — HTTP + WebSocket сервер
  - `clap` — CLI парсинг
  - `tokio` — async runtime
  - `serde` / `serde_json` — сериализация
  - `tokio-tungstenite` — WS клиент (CLI side)
  - `sqlx` + SQLite — хранение устройств и токенов
- **iOS:** Swift + SwiftUI

## Один бинарник

```bash
# Установка
cargo install open-mobile-cli

# Сервер
omcli serve                          # запуск на :7333
omcli serve --port 8080              # кастомный порт
omcli serve --bind 0.0.0.0           # слушать все интерфейсы

# Пейринг
omcli pair <code>                    # привязать устройство
omcli devices                        # список устройств

# Команды
omcli alarm start --sound loud
omcli alarm start --sound hell --message "ВСТАВАЙ"
omcli alarm stop
omcli locate
omcli notify "Привет" --priority critical
omcli tts "Вставай на пары"
omcli camera snap --facing front
omcli status

# Конфиг
omcli config                         # показать текущий
omcli config set server http://localhost:7333
omcli config set token <api-key>
```

## Структура проекта

```
open-mobile-cli/
├── Cargo.toml
├── src/
│   ├── main.rs              # entry point, clap CLI
│   ├── cli/                 # CLI команды
│   │   ├── mod.rs
│   │   ├── alarm.rs
│   │   ├── notify.rs
│   │   ├── locate.rs
│   │   ├── camera.rs
│   │   ├── tts.rs
│   │   ├── status.rs
│   │   ├── pair.rs
│   │   ├── devices.rs
│   │   └── config.rs
│   ├── server/              # Backend (omcli serve)
│   │   ├── mod.rs
│   │   ├── app.rs           # axum router setup
│   │   ├── ws_device.rs     # WebSocket handler для устройств
│   │   ├── ws_client.rs     # WebSocket handler для CLI real-time
│   │   ├── api.rs           # REST endpoints
│   │   └── auth.rs          # pairing + token auth
│   ├── protocol/            # Общие типы
│   │   ├── mod.rs
│   │   ├── command.rs       # Command, Response, Event enums
│   │   └── message.rs       # WS message types
│   └── db/                  # SQLite storage
│       ├── mod.rs
│       └── models.rs
├── ios/                     # iOS приложение
│   └── OpenMobileCLI/
│       ├── OpenMobileCLIApp.swift
│       ├── Services/
│       │   ├── WebSocketService.swift
│       │   ├── AlarmService.swift
│       │   ├── LocationService.swift
│       │   └── CameraService.swift
│       └── Views/
│           ├── DashboardView.swift
│           ├── PairingView.swift
│           └── SettingsView.swift
├── protocol/
│   └── PROTOCOL.md
├── docs/
│   └── ARCHITECTURE.md
└── README.md
```

## Backend API

### REST

```
POST   /api/command              — отправить команду на устройство
GET    /api/status               — статус сервера
GET    /api/devices              — список устройств
POST   /api/devices/pair         — подтвердить пейринг { code: "123456" }
DELETE /api/devices/:id          — удалить устройство
```

### WebSocket

```
WS /ws/device    — подключение устройства (iOS app)
WS /ws/client    — подключение клиента (real-time события)
```

### Аутентификация

- Сервер при первом запуске генерит API key → `~/.omcli/config.toml`
- CLI читает ключ из конфига
- Устройство при пейринге получает device_token
- Все запросы через `Authorization: Bearer <token>`

## Протокол (WebSocket JSON)

```rust
// Команда
{ "id": "uuid", "type": "command", "command": "alarm.start", "params": { "sound": "loud" } }

// Ответ
{ "id": "uuid", "type": "response", "status": "ok", "data": { ... } }

// Событие  
{ "type": "event", "event": "alarm.dismissed", "data": { "dismissed_at": "ISO-8601" } }
```

## Команды v1

| Command | Params | Response/Events |
|---------|--------|-----------------|
| `alarm.start` | `sound: default\|loud\|hell`, `message?` | → `alarm.dismissed`, `alarm.snoozed` |
| `alarm.stop` | — | — |
| `notify.send` | `title`, `body`, `priority?` | — |
| `tts.speak` | `text`, `voice?` | — |
| `location.get` | `accuracy?: coarse\|precise` | `{ lat, lon, accuracy }` |
| `camera.snap` | `facing?: front\|back` | `{ base64, format }` |
| `device.status` | — | `{ battery, charging, silent_mode }` |

## iOS Critical Alerts

Для будильника который звучит в "Не беспокоить" нужен Critical Alerts entitlement от Apple.
Подаётся заявка. Альтернатива: audio session + background mode.

## Roadmap

### v0.1 — MVP
- [ ] `omcli serve` — WebSocket relay + REST API + SQLite
- [ ] `omcli alarm/notify/status` — базовые CLI команды
- [ ] iOS: подключение, будильник, push

### v0.2 — Расширение
- [ ] location, camera, tts
- [ ] mDNS auto-discovery в локалке
- [ ] iOS background reconnect

### v0.3 — Интеграции
- [ ] OpenClaw skill
- [ ] Webhook callbacks
- [ ] Несколько устройств
- [ ] Android клиент
