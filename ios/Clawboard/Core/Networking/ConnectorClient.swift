import Foundation

final class ConnectorClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSnapshot(for scenario: DemoScenario, bridgeConnection: BridgeConnection?) async throws -> AppSnapshot {
        if let bridgeConnection {
            return try await fetchSnapshotFromBridge(bridgeConnection)
        }

        try await Task.sleep(for: .milliseconds(650))

        switch scenario {
        case .normal:
            return MockData.normalSnapshot
        case .empty:
            return MockData.emptySnapshot
        case .error:
            throw URLError(.cannotConnectToHost)
        }
    }

    func fetchPairSession(baseURL: String) async throws -> BridgePairSession {
        let request = try makeRequest(baseURL: baseURL, path: "/pair/session")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(BridgePairSession.self, from: data)
    }

    func exchangePairCode(baseURL: String, payload: BridgePairExchangeRequest) async throws -> BridgePairExchangeResponse {
        var request = try makeRequest(baseURL: baseURL, path: "/pair/exchange")
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(BridgePairExchangeResponse.self, from: data)
    }

    private func fetchSnapshotFromBridge(_ bridgeConnection: BridgeConnection) async throws -> AppSnapshot {
        async let lobstersResponse: LobsterListResponse = fetchAuthorized(bridgeConnection, path: "/lobsters")
        async let tasksResponse: TaskListResponse = fetchAuthorized(bridgeConnection, path: "/tasks")
        async let approvalsResponse: ApprovalListResponse = fetchAuthorized(bridgeConnection, path: "/approvals")
        async let alertsResponse: AlertListResponse = fetchAuthorized(bridgeConnection, path: "/alerts")
        async let nodeInfo: BridgeDeviceInfo = fetchAuthorized(bridgeConnection, path: "/device/info")

        let (lobstersPayload, tasksPayload, approvalsPayload, alertsPayload, deviceInfo) = try await (
            lobstersResponse,
            tasksResponse,
            approvalsResponse,
            alertsResponse,
            nodeInfo
        )

        let lobsterNameByID = Dictionary(uniqueKeysWithValues: lobstersPayload.items.map { ($0.id, $0.name) })

        let nodeSummary = NodeSummary(
            id: deviceInfo.id,
            name: deviceInfo.name,
            status: "在线",
            latencyText: "直连 Bridge"
        )

        return AppSnapshot(
            lobsters: lobstersPayload.items.map { item in
                LobsterSummary(
                    id: item.id,
                    name: item.name,
                    status: mapLobsterStatus(item.status),
                    taskTitle: item.taskTitle ?? "暂无任务",
                    lastActiveAt: relativeTimeText(from: item.lastActiveAt),
                    riskLevel: mapRiskLevel(item.riskLevel),
                    nodeName: deviceInfo.name
                )
            },
            tasks: tasksPayload.items.map { item in
                TaskSummary(
                    id: item.id,
                    title: item.title,
                    status: item.status,
                    progress: item.progress,
                    lobsterID: item.lobsterID,
                    currentStep: stepText(for: item.currentStep)
                )
            },
            approvals: approvalsPayload.items.map { item in
                ApprovalItem(
                    id: item.id,
                    taskID: item.taskID,
                    lobsterID: item.lobsterID,
                    title: item.title,
                    reason: item.reason,
                    scope: item.scope,
                    riskLevel: mapRiskLevel(item.riskLevel),
                    expiresAt: relativeTimeText(from: item.expiresAt),
                    lobsterName: lobsterNameByID[item.lobsterID] ?? "未知龙虾"
                )
            },
            alerts: alertsPayload.items.map { item in
                AlertItem(
                    id: item.id,
                    level: item.level,
                    title: item.title,
                    summary: item.summary,
                    relatedTaskID: item.relatedID
                )
            },
            nodes: [nodeSummary]
        )
    }

    private func fetchAuthorized<T: Decodable>(_ bridgeConnection: BridgeConnection, path: String) async throws -> T {
        var request = try makeRequest(baseURL: bridgeConnection.baseURL, path: path)
        request.addValue("Bearer \(bridgeConnection.token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func makeRequest(baseURL: String, path: String) throws -> URLRequest {
        let sanitizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: sanitizedBaseURL), let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            if let serverError = try? JSONDecoder().decode(BridgeErrorResponse.self, from: data) {
                throw ConnectorError.server(message: serverError.error.message)
            }
            throw ConnectorError.server(message: "Bridge 返回了错误状态：\(http.statusCode)")
        }
    }

    private func mapLobsterStatus(_ raw: String) -> String {
        switch raw {
        case "busy", "running": return "运行中"
        case "paused": return "已暂停"
        case "error", "failed": return "异常"
        case "waiting_approval": return "待审批"
        case "idle": return "在线"
        default: return "在线"
        }
    }

    private func mapRiskLevel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "high": return "高风险"
        case "medium": return "中风险"
        case "low": return "低风险"
        default: return raw
        }
    }

    private func stepText(for raw: String) -> String {
        switch raw {
        case "crm_export": return "导出 CRM 数据"
        case "aggregate_alerts": return "归并告警"
        case "plan": return "规划任务"
        case "search": return "检索上下文"
        default: return raw.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func relativeTimeText(from isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else { return isoString }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "刚刚" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) 分钟前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) 小时前" }
        return "\((hours / 24)) 天前"
    }
}

enum ConnectorError: LocalizedError {
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        }
    }
}

private struct BridgeErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
    }

    let error: ErrorBody
}

private struct LobsterListResponse: Decodable {
    let items: [BridgeLobsterSummary]
}

private struct BridgeLobsterSummary: Decodable {
    let id: String
    let name: String
    let status: String
    let taskTitle: String?
    let lastActiveAt: String
    let riskLevel: String
    let nodeID: String

    private enum CodingKeys: String, CodingKey {
        case id, name, status
        case taskTitle = "task_title"
        case lastActiveAt = "last_active_at"
        case riskLevel = "risk_level"
        case nodeID = "node_id"
    }
}

private struct TaskListResponse: Decodable {
    let items: [BridgeTaskSummary]
}

private struct BridgeTaskSummary: Decodable {
    let id: String
    let title: String
    let status: String
    let progress: Int
    let lobsterID: String
    let currentStep: String

    private enum CodingKeys: String, CodingKey {
        case id, title, status, progress
        case lobsterID = "lobster_id"
        case currentStep = "current_step"
    }
}

private struct ApprovalListResponse: Decodable {
    let items: [BridgeApprovalSummary]
}

private struct BridgeApprovalSummary: Decodable {
    let id: String
    let taskID: String
    let lobsterID: String
    let title: String
    let reason: String
    let scope: String
    let expiresAt: String
    let riskLevel: String

    private enum CodingKeys: String, CodingKey {
        case id, title, reason, scope
        case taskID = "task_id"
        case lobsterID = "lobster_id"
        case expiresAt = "expires_at"
        case riskLevel = "risk_level"
    }
}

private struct AlertListResponse: Decodable {
    let items: [BridgeAlertSummary]
}

private struct BridgeAlertSummary: Decodable {
    let id: String
    let level: String
    let title: String
    let summary: String
    let relatedType: String?
    let relatedID: String?

    private enum CodingKeys: String, CodingKey {
        case id, level, title, summary
        case relatedType = "related_type"
        case relatedID = "related_id"
    }
}

private struct BridgeDeviceInfo: Decodable {
    let id: String
    let name: String
    let platform: String
}
