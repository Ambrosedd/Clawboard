import Foundation

struct BridgeCredentialRecord: Codable, Hashable {
    let baseURL: String
    let token: String
    let node: BridgeNodeInfo
    let pairedAt: Date

    var connection: BridgeConnection {
        BridgeConnection(baseURL: baseURL, token: token, node: node, pairedAt: pairedAt)
    }

    var summary: BridgeConnectionSummary {
        BridgeConnectionSummary(baseURL: baseURL, node: node, pairedAt: pairedAt)
    }
}

protocol BridgeCredentialStoreProtocol {
    func save(_ record: BridgeCredentialRecord)
    func load() -> BridgeCredentialRecord?
    func clear()
}

struct BridgeCredentialStore: BridgeCredentialStoreProtocol {
    private let storageKey = "clawboard.bridge.credentials"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ record: BridgeCredentialRecord) {
        guard let data = try? encoder.encode(record) else { return }

        // 当前环境先用 UserDefaults 模拟 Keychain 接口边界。
        // 后续在真机环境下可替换为 Keychain 实现，而不用改 ViewModel 逻辑。
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func load() -> BridgeCredentialRecord? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? decoder.decode(BridgeCredentialRecord.self, from: data)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
