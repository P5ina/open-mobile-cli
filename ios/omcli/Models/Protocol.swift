import Foundation

// MARK: - Device → Server messages

enum DeviceMessage: Encodable {
    case hello(deviceId: String, name: String)
    case auth(deviceId: String, token: String)
    case response(id: String, status: String, data: AnyCodable?, error: ErrorInfo?)
    case event(event: String, data: AnyCodable?)
    case pushToken(token: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let deviceId, let name):
            try container.encode("hello", forKey: .type)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encode(name, forKey: .name)
        case .auth(let deviceId, let token):
            try container.encode("auth", forKey: .type)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encode(token, forKey: .token)
        case .response(let id, let status, let data, let error):
            try container.encode("response", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(data, forKey: .data)
            try container.encodeIfPresent(error, forKey: .error)
        case .event(let event, let data):
            try container.encode("event", forKey: .type)
            try container.encode(event, forKey: .event)
            try container.encodeIfPresent(data, forKey: .data)
        case .pushToken(let token):
            try container.encode("push_token", forKey: .type)
            try container.encode(token, forKey: .token)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, deviceId = "device_id", name, token, id, status, data, error, event
    }
}

// MARK: - Server → Device messages

enum ServerMessage: Decodable {
    case pairingCode(code: String)
    case authResult(success: Bool, token: String?, error: String?)
    case command(id: String, command: String, params: [String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "pairing_code":
            let code = try container.decode(String.self, forKey: .code)
            self = .pairingCode(code: code)
        case "auth_result":
            let success = try container.decode(Bool.self, forKey: .success)
            let token = try container.decodeIfPresent(String.self, forKey: .token)
            let error = try container.decodeIfPresent(String.self, forKey: .error)
            self = .authResult(success: success, token: token, error: error)
        case "command":
            let id = try container.decode(String.self, forKey: .id)
            let command = try container.decode(String.self, forKey: .command)
            let params = try container.decodeIfPresent([String: AnyCodable].self, forKey: .params) ?? [:]
            self = .command(id: id, command: command, params: params)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown message type: \(type)"
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, code, success, token, error, id, command, params
    }
}

// MARK: - Supporting types

struct ErrorInfo: Codable {
    let code: String
    let message: String
}

// MARK: - AnyCodable (type-erased JSON value)

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    func stringValue() -> String? { value as? String }
    func intValue() -> Int? { value as? Int }
    func doubleValue() -> Double? { value as? Double }
    func boolValue() -> Bool? { value as? Bool }
}
