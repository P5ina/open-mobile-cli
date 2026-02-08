import UIKit

final class CommandRouter {
    let alarmService: AlarmService
    let sleepService: SleepService
    let locationService: LocationService
    let cameraService: CameraService
    let notificationService: NotificationService
    let ttsService: TTSService

    init(
        alarmService: AlarmService,
        sleepService: SleepService,
        locationService: LocationService,
        cameraService: CameraService,
        notificationService: NotificationService,
        ttsService: TTSService
    ) {
        self.alarmService = alarmService
        self.sleepService = sleepService
        self.locationService = locationService
        self.cameraService = cameraService
        self.notificationService = notificationService
        self.ttsService = ttsService
    }

    func handle(id: String, command: String, params: [String: AnyCodable]) async -> DeviceMessage {
        do {
            let data = try await execute(command: command, params: params)
            return .response(id: id, status: "ok", data: data.map { AnyCodable($0) }, error: nil)
        } catch {
            return .response(
                id: id, status: "error", data: nil,
                error: ErrorInfo(code: errorCode(for: error), message: error.localizedDescription)
            )
        }
    }

    private func execute(command: String, params: [String: AnyCodable]) async throws -> [String: Any]? {
        switch command {
        case "alarm.start":
            let sound = params["sound"]?.stringValue() ?? "default"
            let message = params["message"]?.stringValue()
            alarmService.start(sound: sound, message: message)
            return nil

        case "alarm.stop":
            alarmService.stop()
            return nil

        case "notify.send":
            let title = params["title"]?.stringValue() ?? ""
            let body = params["body"]?.stringValue() ?? ""
            let priority = params["priority"]?.stringValue() ?? "normal"
            try await notificationService.send(title: title, body: body, priority: priority)
            return nil

        case "tts.speak":
            let text = params["text"]?.stringValue() ?? ""
            let voice = params["voice"]?.stringValue()
            await ttsService.speak(text: text, voice: voice)
            return nil

        case "location.get":
            let accuracy = params["accuracy"]?.stringValue() ?? "coarse"
            let result = try await locationService.getLocation(accuracy: accuracy)
            return result.mapValues(\.value)

        case "camera.snap":
            let facing = params["facing"]?.stringValue() ?? "back"
            let result = try await cameraService.takePhoto(facing: facing)
            return result.mapValues(\.value)

        case "sleep.start":
            sleepService.start()
            return nil

        case "sleep.stop":
            sleepService.stop()
            return nil

        case "device.status":
            return deviceStatus()

        default:
            throw CommandError.unknownCommand(command)
        }
    }

    private func deviceStatus() -> [String: Any] {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        return [
            "battery": Int(device.batteryLevel * 100),
            "charging": device.batteryState == .charging || device.batteryState == .full,
            "silent_mode": false, // no public API for silent mode detection
        ]
    }

    private func errorCode(for error: Error) -> String {
        switch error {
        case CameraError.notAuthorized: return "PERMISSION_DENIED"
        case CameraError.userDeclined: return "USER_DECLINED"
        case is CameraError: return "CAMERA_ERROR"
        case let clError as NSError where clError.domain == "kCLErrorDomain": return "LOCATION_ERROR"
        case CommandError.unknownCommand: return "UNKNOWN_COMMAND"
        default: return "INTERNAL_ERROR"
        }
    }
}

enum CommandError: LocalizedError {
    case unknownCommand(String)

    var errorDescription: String? {
        switch self {
        case .unknownCommand(let cmd): return "Unknown command: \(cmd)"
        }
    }
}
