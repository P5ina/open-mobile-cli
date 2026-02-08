import SwiftUI

struct ContentView: View {
    let webSocket: WebSocketService
    let alarmService: AlarmService
    let locationService: LocationService
    let cameraService: CameraService

    var body: some View {
        ZStack {
            TabView {
                Tab("Dashboard", systemImage: "gauge.open.with.lines.needle.33percent") {
                    DashboardView(webSocket: webSocket)
                }

                Tab("Settings", systemImage: "gearshape") {
                    SettingsView(
                        webSocket: webSocket,
                        locationService: locationService,
                        cameraService: cameraService
                    )
                }
            }

            if alarmService.isActive {
                AlarmView(message: alarmService.message) {
                    alarmService.stop()
                    webSocket.sendEvent(
                        event: "alarm.dismissed",
                        data: ["dismissed_at": ISO8601DateFormatter().string(from: Date())]
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: alarmService.isActive)
    }
}
