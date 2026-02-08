import SwiftUI

struct ContentView: View {
    let webSocket: WebSocketService
    let alarmService: AlarmService
    let sleepService: SleepService
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

            if sleepService.isActive && !alarmService.isActive {
                SleepModeView {
                    sleepService.stop()
                    webSocket.sendEvent(
                        event: "sleep.stopped",
                        data: ["stopped_at": ISO8601DateFormatter().string(from: Date())]
                    )
                }
                .transition(.opacity)
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
        .animation(.easeInOut, value: sleepService.isActive)
    }
}
