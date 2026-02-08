# omcli — Remote Phone Control

Open-source CLI + backend + iOS app для удалённого управления телефоном.

## Компоненты

```
┌─────────────┐     HTTP/WS      ┌─────────────┐      WS (persistent)     ┌─────────────┐
│   CLI       │ ──────────────→  │   Backend   │  ←──────────────────────  │  iOS App    │
│  omcli   │                  │  (relay)    │                           │  OpenMobileCLI   │
└─────────────┘                  └─────────────┘                           └─────────────┘
                                       ↑
                                  HTTP API для
                                  интеграций
                                  (OpenClaw, скрипты, CI)
```

## Backend (Relay Server)

Минимальный relay — не хранит состояние, просто маршрутизирует команды.

**Стек:** Go или Node.js (Fastify)
**Порт:** 7333 (по умолчанию)

### API

```
POST /api/command              — отправить команду на телефон
GET  /api/status               — статус подключённых устройств
GET  /api/devices              — список устройств
POST /api/devices/:id/pair     — подтвердить пейринг
WS   /ws/device                — подключение устройства (iOS app)
WS   /ws/client                — подключение клиента (real-time события)
```

### Аутентификация

- Устройство при первом подключении генерит device_id + secret
- Backend выдаёт pairing code (6 цифр)
- CLI подтверждает: `omcli pair <code>`
- Дальше общение по device_token

### Протокол (WebSocket JSON)

```json
// Команда (backend → device)
{
  "id": "uuid",
  "type": "command",
  "command": "alarm.start",
  "params": {
    "sound": "loud",
    "message": "Вставай!"
  }
}

// Ответ (device → backend)
{
  "id": "uuid",
  "type": "response",
  "status": "ok",
  "data": { ... }
}

// Событие (device → backend → client)
{
  "type": "event",
  "event": "alarm.dismissed",
  "data": {
    "dismissedAt": "2026-02-08T09:00:00Z"
  }
}
```

## Команды (v1)

### alarm
```
alarm.start    { sound: "default"|"loud"|"hell", message?: string }
alarm.stop     {}
alarm.status   {}
→ events: alarm.dismissed, alarm.snoozed
```

### notify
```
notify.send    { title: string, body: string, sound?: bool, priority?: "low"|"normal"|"critical" }
```

### tts
```
tts.speak      { text: string, voice?: string }
```

### location
```
location.get   { accuracy?: "coarse"|"precise" }
→ { lat, lon, accuracy, timestamp }
```

### camera
```
camera.snap    { facing?: "front"|"back" }
→ { base64, format }
```

### status
```
device.status  {}
→ { battery, charging, silentMode, online, lastSeen }
```

## CLI

```bash
# Установка
go install github.com/p5ina/omcli@latest
# или
npm install -g omcli

# Настройка
omcli init                     # запуск бэкенда
omcli pair <code>              # привязка устройства

# Использование
omcli alarm start --sound loud
omcli alarm stop
omcli locate
omcli notify "Привет"
omcli tts "Вставай на пары"
omcli camera snap --facing front
omcli status
omcli devices

# Интеграция с другими тулзами
omcli alarm start --sound hell && sleep 300 && omcli alarm stop
```

## iOS App

### Экраны
1. **Onboarding** — QR/код для пейринга с бэкендом
2. **Dashboard** — статус подключения, история команд
3. **Settings** — разрешения (камера, локация, уведомления), сервер URL, звуки

### Разрешения
- Push Notifications (critical alerts для будильника)
- Location (when in use / always)
- Camera
- Microphone (для TTS confirmation)

### Ключевое: Critical Alerts
iOS позволяет приложениям воспроизводить звук **даже в режиме "Не беспокоить"** через Critical Alerts. 
Нужен entitlement от Apple (подаётся заявка). Без этого — обычные notifications, которые можно заглушить.

**Альтернатива:** Persistent local notification + audio session с background mode.

### Background
- WebSocket через URLSessionWebSocketTask (работает в background)
- Background push для wake-up
- Background App Refresh для переподключения

## Структура репозитория

```
omcli/
├── backend/           # Relay server (Go или Node)
│   ├── main.go
│   ├── handlers/
│   ├── ws/
│   └── Dockerfile
├── cli/               # CLI клиент
│   ├── main.go
│   └── commands/
├── ios/               # iOS приложение
│   └── OpenMobileCLI/
│       ├── App.swift
│       ├── Services/
│       │   ├── WebSocketService.swift
│       │   ├── AlarmService.swift
│       │   ├── LocationService.swift
│       │   └── CameraService.swift
│       └── Views/
├── protocol/          # Спецификация протокола
│   └── PROTOCOL.md
└── README.md
```

## Roadmap

### v0.1 — MVP
- [ ] Backend: WebSocket relay, pairing, REST API
- [ ] CLI: alarm, notify, status
- [ ] iOS: подключение, будильник, уведомления

### v0.2 — Расширение
- [ ] Location, camera, TTS
- [ ] CLI: auto-discovery (mDNS в локалке)
- [ ] iOS: background reconnect

### v0.3 — Интеграции
- [ ] OpenClaw skill (omcli)
- [ ] Webhook callback на события
- [ ] Несколько устройств
- [ ] Android клиент

### v1.0 — Публичный релиз
- [ ] Документация
- [ ] Docker image для бэкенда
- [ ] App Store
