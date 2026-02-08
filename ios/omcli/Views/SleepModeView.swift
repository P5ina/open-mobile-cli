import Combine
import SwiftUI

struct SleepModeView: View {
    let onWake: () -> Void

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.3))

                Text(currentTime, format: .dateTime.hour().minute())
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()

                Text("Alarm standby")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.3))

                Spacer()

                Button(action: onWake) {
                    Text("Wake")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .padding(.bottom, 48)
            }
        }
        .onReceive(timer) { currentTime = $0 }
        .persistentSystemOverlays(.hidden)
    }
}
