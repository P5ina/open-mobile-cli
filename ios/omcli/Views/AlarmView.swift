import SwiftUI

struct AlarmView: View {
    let message: String?
    let onDismiss: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.red
                .opacity(pulse ? 0.8 : 1.0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: 32) {
                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .repeating)

                if let message {
                    Text(message)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
        }
        .onAppear { pulse = true }
    }
}
