import Foundation
import UIKit

enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case waitingForPairing
    case paired
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let message: String
}

@Observable
final class WebSocketService: @unchecked Sendable {
    var connectionState: ConnectionState = .disconnected
    var pairingCode: String?
    var lastCommand: String?
    var log: [LogEntry] = []
    var lastError: String?

    @ObservationIgnored private var webSocketTask: URLSessionWebSocketTask?
    @ObservationIgnored private var session: URLSession?
    @ObservationIgnored private var reconnectAttempt = 0
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    @ObservationIgnored private var isIntentionalDisconnect = false
    @ObservationIgnored private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored var commandHandler: (@Sendable (String, String, [String: AnyCodable]) async -> DeviceMessage)?

    private var deviceId: String { KeychainService.getOrCreateDeviceId() }
    private var deviceToken: String? { KeychainService.load(key: .deviceToken) }
    private var serverURL: String { UserDefaults.standard.string(forKey: "server_url") ?? "" }
    private var deviceName: String {
        let name = UserDefaults.standard.string(forKey: "device_name") ?? ""
        return name.isEmpty ? UIDevice.current.name : name
    }

    func connect() {
        guard !serverURL.isEmpty else {
            addLog("No server URL configured")
            return
        }
        isIntentionalDisconnect = false
        reconnectAttempt = 0
        doConnect()
    }

    func disconnect() {
        isIntentionalDisconnect = true
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        endBackgroundTask()
    }

    func sendEvent(event: String, data: [String: Any]) {
        let msg = DeviceMessage.event(event: event, data: AnyCodable(data))
        send(msg)
    }

    // MARK: - Private

    private func doConnect() {
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        connectionState = .connecting
        addLog("Connecting to \(serverURL)...")

        guard let url = URL(string: serverURL) else {
            addLog("Invalid server URL")
            connectionState = .disconnected
            return
        }

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        beginBackgroundTask()
        sendHello()
    }

    private func sendHello() {
        let msg = DeviceMessage.hello(deviceId: deviceId, name: deviceName)
        send(msg) { [weak self] success in
            guard let self, success else { return }
            self.addLog("Sent hello as \(self.deviceName)")
            self.startReceiving()
            // Server reads Hello then enters main loop.
            // If already paired, send Auth immediately.
            if self.deviceToken != nil {
                self.sendAuth()
            }
        }
    }

    private func sendAuth() {
        guard let token = deviceToken else {
            addLog("No token, cannot auth")
            return
        }
        let msg = DeviceMessage.auth(deviceId: deviceId, token: token)
        send(msg) { [weak self] success in
            guard let self, success else { return }
            self.addLog("Sent auth")
        }
    }

    private func send(_ message: DeviceMessage, completion: ((Bool) -> Void)? = nil) {
        guard let data = try? JSONEncoder().encode(message),
              let string = String(data: data, encoding: .utf8) else {
            completion?(false)
            return
        }
        webSocketTask?.send(.string(string)) { [weak self] error in
            if let error {
                self?.addLog("Send error: \(error.localizedDescription)")
                completion?(false)
            } else {
                completion?(true)
            }
        }
    }

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let task = self.webSocketTask else { return }
                do {
                    let message = try await task.receive()
                    await self.handleMessage(message)
                } catch {
                    guard !Task.isCancelled else { return }
                    self.handleDisconnect(error: error)
                    return
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        guard case .string(let text) = message else { return }

        guard let data = text.data(using: .utf8),
              let serverMsg = try? JSONDecoder().decode(ServerMessage.self, from: data) else {
            addLog("Unknown message received")
            return
        }

        switch serverMsg {
        case .pairingCode(let code):
            pairingCode = code
            connectionState = .waitingForPairing
            addLog("Pairing code: \(code)")

        case .authResult(let success, let token, let error):
            if success {
                if let token {
                    KeychainService.save(key: .deviceToken, value: token)
                    addLog("Paired successfully")
                } else {
                    addLog("Authenticated")
                }
                pairingCode = nil
                connectionState = .paired
                reconnectAttempt = 0
            } else {
                addLog("Auth failed: \(error ?? "unknown")")
                KeychainService.delete(key: .deviceToken)
                connectionState = .disconnected
            }

        case .command(let id, let command, let params):
            lastCommand = command
            addLog("Command: \(command)")
            if let handler = commandHandler {
                let response = await handler(id, command, params)
                send(response)
            }
        }
    }

    private func handleDisconnect(error: Error) {
        let nsError = error as NSError
        let wasCancelled = nsError.domain == NSPOSIXErrorDomain && nsError.code == 57
            || nsError.code == 60 || isIntentionalDisconnect

        if !wasCancelled {
            lastError = error.localizedDescription
            addLog("Disconnected: \(error.localizedDescription)")
        }

        connectionState = .disconnected
        endBackgroundTask()

        if !isIntentionalDisconnect {
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        reconnectAttempt += 1
        addLog("Reconnecting in \(Int(delay))s...")

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.doConnect()
        }
    }

    private func addLog(_ message: String) {
        log.insert(LogEntry(message: message), at: 0)
        if log.count > 100 { log.removeLast() }
    }

    // MARK: - Background task

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
}
