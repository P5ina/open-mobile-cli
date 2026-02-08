import SwiftUI

struct PairingView: View {
    let code: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "link.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Pairing Code")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(code)
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .kerning(12)
                .padding(.horizontal)

            Text("Enter this code in CLI:")
                .foregroundStyle(.secondary)
            Text("omcli pair \(code)")
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(.fill, in: RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding()
    }
}
