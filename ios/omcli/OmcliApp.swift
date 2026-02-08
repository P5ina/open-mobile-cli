import SwiftUI

@main
struct OmcliApp: App {
    @State private var webSocket = WebSocketService()
    @State private var alarmService = AlarmService()
    private let locationService = LocationService()
    private let cameraService = CameraService()
    private let notificationService = NotificationService()
    private let ttsService = TTSService()

    var body: some Scene {
        WindowGroup {
            ContentView(
                webSocket: webSocket,
                alarmService: alarmService,
                locationService: locationService,
                cameraService: cameraService
            )
            .task { await setup() }
        }
    }

    private func setup() async {
        let router = CommandRouter(
            alarmService: alarmService,
            locationService: locationService,
            cameraService: cameraService,
            notificationService: notificationService,
            ttsService: ttsService
        )

        webSocket.commandHandler = { id, command, params in
            await router.handle(id: id, command: command, params: params)
        }

        // Request notification permission early
        _ = await notificationService.requestPermission()

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
