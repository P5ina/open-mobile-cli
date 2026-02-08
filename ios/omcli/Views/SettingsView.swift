import SwiftUI
import AVFoundation
import CoreLocation

struct SettingsView: View {
    let webSocket: WebSocketService
    let locationService: LocationService
    let cameraService: CameraService

    @AppStorage("server_url") private var serverURL = ""
    @AppStorage("device_name") private var deviceName = ""

    @State private var notificationStatus = "Unknown"
    @State private var showResetConfirm = false
    @State private var discovery = ServerDiscoveryService()

    var body: some View {
        NavigationStack {
            Form {
                if !discovery.servers.isEmpty || discovery.isSearching {
                    Section {
                        if discovery.servers.isEmpty {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text("Searching for servers...")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(discovery.servers) { server in
                            Button {
                                if let url = server.wsURL {
                                    serverURL = url
                                    webSocket.disconnect()
                                    webSocket.connect()
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(server.name)
                                        if let host = server.host, let port = server.port {
                                            Text("\(host):\(port)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let version = server.version {
                                            Text("v\(version)")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    Spacer()
                                    if server.wsURL == serverURL {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .disabled(server.wsURL == nil)
                            .tint(.primary)
                        }
                    } header: {
                        HStack {
                            Text("Discovered Servers")
                            Spacer()
                            if discovery.isSearching && !discovery.servers.isEmpty {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }
                    }
                }

                Section("Server") {
                    TextField("WebSocket URL", text: $serverURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    if serverURL.isEmpty {
                        Text("Example: ws://192.168.1.100:7333/ws/device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Device") {
                    TextField("Device name", text: $deviceName, prompt: Text(UIDevice.current.name))
                        .autocorrectionDisabled()

                    LabeledContent("Device ID") {
                        Text(KeychainService.getOrCreateDeviceId().prefix(8) + "...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Permissions") {
                    PermissionRow(
                        title: "Location",
                        status: locationPermissionStatus,
                        icon: "location.fill"
                    )
                    PermissionRow(
                        title: "Camera",
                        status: cameraPermissionStatus,
                        icon: "camera.fill"
                    )
                    PermissionRow(
                        title: "Notifications",
                        status: notificationStatus,
                        icon: "bell.fill"
                    )

                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section {
                    Button("Reconnect") {
                        webSocket.disconnect()
                        webSocket.connect()
                    }

                    Button("Unpair Device", role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Unpair device?", isPresented: $showResetConfirm) {
                Button("Unpair", role: .destructive) {
                    webSocket.disconnect()
                    KeychainService.delete(key: .deviceToken)
                }
            } message: {
                Text("This will remove the device token. You'll need to pair again.")
            }
            .onAppear { discovery.startBrowsing() }
            .onDisappear { discovery.stopBrowsing() }
            .task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                notificationStatus = switch settings.authorizationStatus {
                case .authorized: "Authorized"
                case .denied: "Denied"
                case .notDetermined: "Not requested"
                case .provisional: "Provisional"
                default: "Unknown"
                }
            }
        }
    }

    private var locationPermissionStatus: String {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse: "When In Use"
        case .authorizedAlways: "Always"
        case .denied, .restricted: "Denied"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }

    private var cameraPermissionStatus: String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: "Authorized"
        case .denied, .restricted: "Denied"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let status: String
    let icon: String

    var body: some View {
        LabeledContent {
            Text(status)
                .foregroundStyle(status == "Denied" ? .red : .secondary)
        } label: {
            Label(title, systemImage: icon)
        }
    }
}
