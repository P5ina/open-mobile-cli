import Foundation
import Network

struct DiscoveredServer: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var host: String?
    var port: UInt16?
    var wsPath: String
    var version: String?

    var wsURL: String? {
        guard let host, let port else { return nil }
        return "ws://\(host):\(port)\(wsPath)"
    }
}

@Observable
final class ServerDiscoveryService {
    var servers: [DiscoveredServer] = []
    var isSearching = false

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private let queue = DispatchQueue(label: "omcli.discovery")

    func startBrowsing() {
        guard browser == nil else { return }

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_omcli._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: NWParameters())

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .ready:
                    self.isSearching = true
                case .failed, .cancelled:
                    self.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            let paired = self.parseResults(results)
            Task { @MainActor in
                self.applyResults(paired.map(\.server))
            }
            for (result, server) in paired {
                self.resolve(result: result, serverId: server.id)
            }
        }

        browser.start(queue: queue)
        self.browser = browser
        isSearching = true
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isSearching = false
        servers = []
    }

    // Called on `queue` — no @MainActor access, returns plain data paired with browse results
    nonisolated private func parseResults(_ results: Set<NWBrowser.Result>) -> [(result: NWBrowser.Result, server: DiscoveredServer)] {
        var paired = [(result: NWBrowser.Result, server: DiscoveredServer)]()
        for result in results {
            guard case .service(let name, let type, _, _) = result.endpoint else { continue }
            let id = "\(name).\(type)"
            var server = DiscoveredServer(id: id, name: name, wsPath: "/ws/device")
            if case .bonjour(let txt) = result.metadata {
                let dict = txt.dictionary
                if let path = dict["path"] { server.wsPath = path }
                if let ver = dict["version"] { server.version = ver }
            }
            paired.append((result, server))
        }
        return paired
    }

    // Called on MainActor
    private func applyResults(_ parsed: [DiscoveredServer]) {
        var updated = parsed
        for i in updated.indices {
            if let existing = servers.first(where: { $0.id == updated[i].id }) {
                updated[i].host = updated[i].host ?? existing.host
                updated[i].port = updated[i].port ?? existing.port
            }
        }
        servers = updated
    }

    nonisolated private func resolve(result: NWBrowser.Result, serverId: String) {
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    let hostStr = "\(host)"
                        .replacingOccurrences(of: "%.*", with: "", options: .regularExpression)
                    let portVal = port.rawValue
                    Task { @MainActor in
                        if let idx = self?.servers.firstIndex(where: { $0.id == serverId }) {
                            self?.servers[idx].host = hostStr
                            self?.servers[idx].port = portVal
                        }
                    }
                }
                connection.cancel()
            case .failed:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }
}
