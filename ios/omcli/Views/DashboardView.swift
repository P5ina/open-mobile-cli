import SwiftUI

struct DashboardView: View {
    let webSocket: WebSocketService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(statusText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if webSocket.connectionState == .disconnected {
                            Button("Connect") { webSocket.connect() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }

                    if let deviceName = UserDefaults.standard.string(forKey: "device_name"),
                       !deviceName.isEmpty {
                        LabeledContent("Device", value: deviceName)
                    }

                    if let lastCommand = webSocket.lastCommand {
                        LabeledContent("Last command", value: lastCommand)
                    }
                } header: {
                    Text("Status")
                }

                if let code = webSocket.pairingCode {
                    Section {
                        VStack(spacing: 12) {
                            Text("Pairing Code")
                                .font(.headline)
                            Text(code)
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .kerning(8)
                            Text("Enter this code in CLI: omcli pair \(code)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }

                if !webSocket.log.isEmpty {
                    Section {
                        ForEach(webSocket.log) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                                Text(entry.message)
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("Log")
                    }
                }
            }
            .navigationTitle("Dashboard")
        }
    }

    private var statusColor: Color {
        switch webSocket.connectionState {
        case .paired: .green
        case .connecting, .waitingForPairing: .orange
        case .disconnected: .red
        }
    }

    private var statusText: String {
        switch webSocket.connectionState {
        case .paired: "Connected"
        case .connecting: "Connecting..."
        case .waitingForPairing: "Waiting for pairing"
        case .disconnected: "Disconnected"
        }
    }
}
