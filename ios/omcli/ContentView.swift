import SwiftUI
import UIKit

struct ContentView: View {
    let webSocket: WebSocketService
    let alarmService: AlarmService
    let callService: CallService
    let sleepService: SleepService
    let locationService: LocationService
    let cameraService: CameraService
    let notificationService: NotificationService

    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            mainContent
        } else {
            OnboardingView(
                notificationService: notificationService,
                locationService: locationService,
                cameraService: cameraService,
                onNotificationsGranted: {
                    UIApplication.shared.registerForRemoteNotifications()
                },
                onComplete: {
                    hasCompletedOnboarding = true
                }
            )
        }
    }

    private var mainContent: some View {
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
                    callService.endActiveCall()
                    webSocket.sendEvent(
                        event: "alarm.dismissed",
                        data: ["dismissed_at": ISO8601DateFormatter().string(from: Date())]
                    )
                }
                .transition(.opacity)
            }

            if cameraService.isShowingPreview {
                CameraPreviewView(cameraService: cameraService)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: alarmService.isActive)
        .animation(.easeInOut, value: sleepService.isActive)
        .animation(.easeInOut, value: cameraService.isShowingPreview)
    }
}
