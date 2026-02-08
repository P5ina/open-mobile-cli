import SwiftUI
import UIKit

@main
struct OmcliApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var webSocket = WebSocketService()
    @State private var alarmService = AlarmService()
    @State private var sleepService = SleepService()
    private let locationService = LocationService()
    private let cameraService = CameraService()
    private let notificationService = NotificationService()
    private let ttsService = TTSService()

    var body: some Scene {
        WindowGroup {
            ContentView(
                webSocket: webSocket,
                alarmService: alarmService,
                sleepService: sleepService,
                locationService: locationService,
                cameraService: cameraService
            )
            .task { await setup() }
        }
    }

    private func setup() async {
        appDelegate.webSocket = webSocket
        appDelegate.alarmService = alarmService

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

        // Request notification permission early
        let granted = await notificationService.requestPermission()

        // Register for remote notifications if permission granted
        if granted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        // Request location permission
        locationService.requestPermissionIfNeeded()

        // Request camera permission
        cameraService.requestPermissionIfNeeded()

        // Auto-connect if server URL is configured
        let serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
        if !serverURL.isEmpty {
            webSocket.connect()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var webSocket: WebSocketService?
    var alarmService: AlarmService?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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
