import SwiftUI
import UIKit

@main
struct OmcliApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var webSocket = WebSocketService()
    @State private var alarmService = AlarmService()
    @State private var sleepService = SleepService()
    private let locationService = LocationService()
    @State private var cameraService = CameraService()
    private let notificationService = NotificationService()
    private let ttsService = TTSService()

    var body: some Scene {
        WindowGroup {
            ContentView(
                webSocket: webSocket,
                alarmService: alarmService,
                callService: appDelegate.callService,
                sleepService: sleepService,
                locationService: locationService,
                cameraService: cameraService,
                notificationService: notificationService
            )
            .task { await setup() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                webSocket.connect()
            case .background:
                webSocket.disconnect()
            default:
                break
            }
        }
    }

    private func setup() async {
        appDelegate.webSocket = webSocket
        appDelegate.alarmService = alarmService

        // CallService.setup() already called in didFinishLaunchingWithOptions — wire callbacks
        let callService = appDelegate.callService
        callService.sendVoipToken = { token in webSocket.sendVoipToken(token) }
        callService.onAlarmAnswer = { sound, message in
            alarmService.start(sound: sound ?? "loud", message: message)
        }
        callService.onAlarmDecline = {
            alarmService.stop()
        }

        let router = CommandRouter(
            alarmService: alarmService,
            sleepService: sleepService,
            locationService: locationService,
            cameraService: cameraService,
            notificationService: notificationService,
            ttsService: ttsService
        )

        webSocket.commandHandler = { id, command, params in
            await router.handle(id: id, command: command, params: params)
        }

        // Migrate old global token to per-server storage
        let serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
        if !serverURL.isEmpty {
            if let oldToken = KeychainService.load(key: .deviceToken),
               KeychainService.loadToken(for: serverURL) == nil {
                KeychainService.saveToken(oldToken, for: serverURL)
                KeychainService.delete(key: .deviceToken)
            }
            webSocket.connect()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var webSocket: WebSocketService?
    var alarmService: AlarmService?
    let callService = CallService()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // PushKit + CallKit must be ready before any VoIP push can arrive
        callService.setup()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs token: \(token)")
        webSocket?.sendPushToken(token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let omcli = userInfo["omcli"] as? [String: Any],
           let command = omcli["command"] as? String,
           command.hasPrefix("alarm.") {
            let params = omcli["params"] as? [String: Any] ?? [:]
            if command == "alarm.start" {
                let sound = params["sound"] as? String ?? "default"
                let message = params["message"] as? String
                alarmService?.start(sound: sound, message: message)
            } else if command == "alarm.stop" {
                alarmService?.stop()
            }
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "STOP_ALARM" {
            alarmService?.stop()
            webSocket?.sendEvent(
                event: "alarm.dismissed",
                data: ["dismissed_at": ISO8601DateFormatter().string(from: Date())]
            )
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
