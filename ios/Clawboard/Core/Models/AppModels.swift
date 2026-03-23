import Foundation
import SwiftUI

struct LobsterSummary: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var status: String
    var taskTitle: String
    var lastActiveAt: String
    var riskLevel: String
    var nodeName: String
}

struct TaskSummary: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var status: String
    var progress: Int
    var lobsterID: String
    var currentStep: String
}

struct ApprovalItem: Identifiable, Codable, Hashable {
    let id: String
    let taskID: String
    let lobsterID: String
    let title: String
    let reason: String
    let scope: String
    let riskLevel: String
    let expiresAt: String
    let lobsterName: String
}

struct AlertItem: Identifiable, Codable, Hashable {
    let id: String
    let level: String
    let title: String
    let summary: String
    let relatedTaskID: String?
}

struct NodeSummary: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let status: String
    let latencyText: String
}

struct TaskTimelineStep: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let state: String
}

struct AppSnapshot: Codable, Hashable {
    let lobsters: [LobsterSummary]
    let tasks: [TaskSummary]
    let approvals: [ApprovalItem]
    let alerts: [AlertItem]
    let nodes: [NodeSummary]
}

struct BridgePairSession: Codable, Hashable {
    let pairingID: String
    let pairCode: String
    let expiresAt: String
    let nodeID: String
    let displayName: String
    let bridgeVersion: String
    let networkHint: String
    let bridgeURL: String?
    let pairingLink: String?

    private enum CodingKeys: String, CodingKey {
        case pairingID = "pairing_id"
        case pairCode = "pair_code"
        case expiresAt = "expires_at"
        case nodeID = "node_id"
        case displayName = "display_name"
        case bridgeVersion = "bridge_version"
        case networkHint = "network_hint"
        case bridgeURL = "bridge_url"
        case pairingLink = "pairing_link"
    }
}

struct BridgeNodeInfo: Codable, Hashable {
    let id: String
    let name: String
    let platform: String
}

struct BridgePairExchangeRequest: Codable, Hashable {
    let pairCode: String
    let deviceName: String
    let clientName: String
    let clientVersion: String

    private enum CodingKeys: String, CodingKey {
        case pairCode = "pair_code"
        case deviceName = "device_name"
        case clientName = "client_name"
        case clientVersion = "client_version"
    }
}

struct BridgePairExchangeResponse: Codable, Hashable {
    let token: String
    let tokenType: String
    let issuedAt: String
    let node: BridgeNodeInfo

    private enum CodingKeys: String, CodingKey {
        case token
        case tokenType = "token_type"
        case issuedAt = "issued_at"
        case node
    }
}

struct BridgeConnection: Codable, Hashable {
    let baseURL: String
    let token: String
    let node: BridgeNodeInfo
    let pairedAt: Date
}

struct BridgeConnectionSummary: Codable, Hashable {
    let baseURL: String
    let node: BridgeNodeInfo
    let pairedAt: Date
}

struct BridgePairingPayload: Hashable {
    let baseURL: String
    let pairCode: String

    static func parse(from raw: String) -> BridgePairingPayload? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme?.lowercased() == "clawboard",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let items = components.queryItems ?? []
            let code = items.first(where: { $0.name == "code" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseURL = items.first(where: { $0.name == "url" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let code, !code.isEmpty, let baseURL, !baseURL.isEmpty {
                return BridgePairingPayload(baseURL: baseURL, pairCode: code)
            }
        }

        let lines = trimmed
            .split(whereSeparator: \ .isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var detectedCode: String?
        var detectedURL: String?
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("clawboard://") {
                return parse(from: line)
            }
            if lower.contains("http://") || lower.contains("https://") {
                detectedURL = line
            }
            if lower.hasPrefix("配对码:") || lower.hasPrefix("pair code:") {
                detectedCode = line.split(separator: ":", maxSplits: 1).last.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            if lower.hasPrefix("bridge 地址:") || lower.hasPrefix("bridge url:") || lower.hasPrefix("url:") {
                detectedURL = line.split(separator: ":", maxSplits: 1).dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let detectedCode, let detectedURL, !detectedCode.isEmpty, !detectedURL.isEmpty {
            return BridgePairingPayload(baseURL: detectedURL, pairCode: detectedCode)
        }

        return nil
    }
}

struct PersistedAppState: Codable {
    let scenario: DemoScenario
    let snapshot: AppSnapshot
    let savedAt: Date
    let autoplayEnabled: Bool
    let bridgeConnectionSummary: BridgeConnectionSummary?

    init(scenario: DemoScenario, snapshot: AppSnapshot, savedAt: Date, autoplayEnabled: Bool, bridgeConnectionSummary: BridgeConnectionSummary?) {
        self.scenario = scenario
        self.snapshot = snapshot
        self.savedAt = savedAt
        self.autoplayEnabled = autoplayEnabled
        self.bridgeConnectionSummary = bridgeConnectionSummary
    }

    private enum CodingKeys: String, CodingKey {
        case scenario, snapshot, savedAt, autoplayEnabled, bridgeConnectionSummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scenario = try container.decode(DemoScenario.self, forKey: .scenario)
        snapshot = try container.decode(AppSnapshot.self, forKey: .snapshot)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        autoplayEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoplayEnabled) ?? true
        bridgeConnectionSummary = try container.decodeIfPresent(BridgeConnectionSummary.self, forKey: .bridgeConnectionSummary)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scenario, forKey: .scenario)
        try container.encode(snapshot, forKey: .snapshot)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(autoplayEnabled, forKey: .autoplayEnabled)
        try container.encodeIfPresent(bridgeConnectionSummary, forKey: .bridgeConnectionSummary)
    }
}

enum AppLoadPhase: Equatable {
    case idle
    case loading
    case loaded
    case restoring
    case failed(String)

    var isBlocking: Bool {
        if case .loading = self { return true }
        if case .idle = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

enum DemoScenario: String, CaseIterable, Identifiable, Codable {
    case normal = "normal"
    case empty = "empty"
    case error = "error"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "标准演示"
        case .empty: return "空状态演示"
        case .error: return "错误恢复演示"
        }
    }

    var description: String {
        switch self {
        case .normal:
            return "展示审批、任务、节点与告警联动。"
        case .empty:
            return "模拟任务已清空、审批已处理完成后的安静状态。"
        case .error:
            return "模拟 Bridge 暂时不可用，验证重试与错误提示。"
        }
    }
}

extension BridgeConnection {
    var summary: BridgeConnectionSummary {
        BridgeConnectionSummary(baseURL: baseURL, node: node, pairedAt: pairedAt)
    }
}

extension TaskSummary {
    var statusLabel: String {
        switch status {
        case "running": return "运行中"
        case "waiting_approval": return "待审批"
        case "paused": return "已暂停"
        case "failed": return "异常"
        case "completed": return "已完成"
        case "terminated": return "已终止"
        default: return status
        }
    }

    var statusTone: Color {
        switch status {
        case "running": return AppTheme.brand
        case "waiting_approval": return AppTheme.warning
        case "paused": return Color.purple
        case "failed", "terminated": return AppTheme.danger
        case "completed": return AppTheme.success
        default: return Color.gray
        }
    }
}

extension LobsterSummary {
    var statusTone: Color {
        switch status {
        case "运行中": return AppTheme.brand
        case "待审批": return AppTheme.warning
        case "异常": return AppTheme.danger
        case "已暂停": return Color.purple
        case "已完成": return AppTheme.success
        default: return Color.gray
        }
    }
}

extension NodeSummary {
    var statusTone: Color {
        switch status {
        case "在线": return AppTheme.success
        case "延迟较高": return AppTheme.warning
        case "异常": return AppTheme.danger
        default: return Color.gray
        }
    }
}

extension ApprovalItem {
    var riskTone: Color {
        riskLevel == "高风险" ? AppTheme.danger : AppTheme.warning
    }
}
