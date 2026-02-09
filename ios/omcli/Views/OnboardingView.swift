import SwiftUI

struct OnboardingView: View {
    let notificationService: NotificationService
    let locationService: LocationService
    let cameraService: CameraService
    var onNotificationsGranted: () -> Void
    var onComplete: () -> Void

    @State private var currentStep = 0

    var body: some View {
        TabView(selection: $currentStep) {
            welcomeStep.tag(0)
            notificationStep.tag(1)
            locationStep.tag(2)
            cameraStep.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        OnboardingStepView(
            icon: "terminal",
            title: "omcli",
            description: "Control your phone from the terminal.",
            buttonLabel: "Get Started",
            action: { advance() },
            skipAction: nil
        )
    }

    private var notificationStep: some View {
        OnboardingStepView(
            icon: "bell.badge.fill",
            title: "Notifications",
            description: "Receive alerts, alarms, and messages even when the app is in the background.",
            buttonLabel: "Allow Notifications",
            action: {
                Task {
                    let granted = await notificationService.requestPermission()
                    if granted { onNotificationsGranted() }
                    advance()
                }
            },
            skipAction: { advance() }
        )
    }

    private var locationStep: some View {
        OnboardingStepView(
            icon: "location.fill",
            title: "Location",
            description: "Share your device location when requested from the CLI.",
            buttonLabel: "Allow Location",
            action: {
                locationService.requestPermissionIfNeeded()
                advance()
            },
            skipAction: { advance() }
        )
    }

    private var cameraStep: some View {
        OnboardingStepView(
            icon: "camera.fill",
            title: "Camera",
            description: "Take photos remotely when requested from the CLI.",
            buttonLabel: "Allow & Finish",
            action: {
                cameraService.requestPermissionIfNeeded()
                onComplete()
            },
            skipAction: { onComplete() }
        )
    }

    private func advance() {
        withAnimation {
            currentStep += 1
        }
    }
}

// MARK: - Reusable step layout

private struct OnboardingStepView: View {
    let icon: String
    let title: String
    let description: String
    let buttonLabel: String
    let action: () -> Void
    let skipAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text(title)
                .font(.largeTitle.bold())

            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: action) {
                Text(buttonLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)

            if let skipAction {
                Button("Skip", action: skipAction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 40)
        }
    }
}
