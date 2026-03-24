import Foundation

enum ConnectorError: LocalizedError, Equatable {
    case unauthorized(AuthDiagnostics?)
    case pairSessionExpired
    case bridgeUnavailable
    case invalidResponse
    case server(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized(let diagnostics):
            if diagnostics?.pairSession.state == "expired" {
                return "当前会话已失效，且配对会话已过期，请重新获取连接信息"
            }
            if diagnostics?.authState == "revoked" {
                return "当前 token 已被撤销，请重新连接 Bridge"
            }
            return "当前会话已失效，请重新连接 Bridge"
        case .pairSessionExpired:
            return "配对会话已过期，请重新获取配对信息"
        case .bridgeUnavailable:
            return "暂时无法连接 Bridge，请检查网络、Tunnel 或服务状态"
        case .invalidResponse:
            return "Bridge 返回了无法识别的响应"
        case .server(_, let message):
            return message
        }
    }

    var userFacingMessage: String {
        switch self {
        case .unauthorized(let diagnostics):
            if diagnostics?.pairSession.state == "expired" {
                return "配对已过期，请重新获取连接串"
            }
            if diagnostics?.authState == "revoked" {
                return "当前会话已被撤销，请重新连接"
            }
            return "当前会话已失效，请重新连接"
        case .pairSessionExpired:
            return "配对已过期，请重新获取连接串"
        case .bridgeUnavailable:
            return "Bridge 当前不可达，请检查网络或 Tunnel"
        case .invalidResponse:
            return "Bridge 返回了异常响应，请稍后重试"
        case .server(let code, let message):
            if code == "unauthorized" {
                return "当前会话已失效，请重新连接"
            }
            return message
        }
    }
}

final class ConnectorClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSnapshot(for scenario: DemoScenario, bridgeConnection: BridgeConnection?) async throws -> AppSnapshot {
        if let bridgeConnection {
            return try await fetchSnapshotFromBridge(bridgeConnection)
        }

        #if DEBUG
        try await Task.sleep(for: .milliseconds(650))

        switch scenario {
        case .normal:
            return MockData.normalSnapshot
        case .empty:
            return MockData.emptySnapshot
        case .error:
            throw URLError(.cannotConnectToHost)
        }
        #else
        throw ConnectorError.bridgeUnavailable
        #endif
    }

    func fetchPairSession(baseURL: String) async throws -> BridgePairSession {
        let request = try makeRequest(baseURL: baseURL, path: "/pair/session")
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            return try JSONDecoder().decode(BridgePairSession.self, from: data)
        } catch {
            throw mapNetworkError(error)
        }
    }

    func exchangePairCode(baseURL: String, payload: BridgePairExchangeRequest) async throws -> BridgePairExchangeResponse {
        var request = try makeRequest(baseURL: baseURL, path: "/pair/exchange")
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            return try JSONDecoder().decode(BridgePairExchangeResponse.self, from: data)
        } catch {
            throw mapNetworkError(error)
        }
    }

    func revokeCurrentToken(_ bridgeConnection: BridgeConnection) async throws {
        var request = try makeRequest(baseURL: bridgeConnection.baseURL, path: "/auth/revoke")
        request.httpMethod = "POST"
        request.addValue("Bearer \(bridgeConnection.token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
        } catch {
            throw mapNetworkError(error)
        }
    }

    func approve(
        _ approval: ApprovalItem,
        on bridgeConnection: BridgeConnection,
        grantedScope: String? = nil,
        durationMinutes: Int = 30,
        capabilityKind: TemporaryCapabilityKind = .directoryAccess,
        commandAlias: String? = nil,
        restartAfterGrant: Bool = false
    ) async throws {
        let payload = BridgeApproveRequest(
            grantedScope: grantedScope ?? approval.scope,
            durationMinutes: durationMinutes,
            capabilityKind: capabilityKind.rawValue,
            commandAlias: commandAlias,
            restartAfterGrant: restartAfterGrant
        )
        try await sendAuthorized(
            bridgeConnection,
            path: "/approvals/\(approval.id)/approve",
            method: "POST",
            body: payload
        )
    }

    func restart(lobsterID: String, on bridgeConnection: BridgeConnection) async throws {
        try await sendTaskControl(path: "/lobsters/\(lobsterID)/restart", on: bridgeConnection)
    }

    func fetchDeviceCapabilities(on bridgeConnection: BridgeConnection) async throws -> BridgeDeviceInfo {
        try await fetchAuthorized(bridgeConnection, path: "/device/info")
    }

    func fetchCapabilityLeases(on bridgeConnection: BridgeConnection) async throws -> CapabilityLeaseListResponse {
        try await fetchAuthorized(bridgeConnection, path: "/capabilities/leases")
    }

    func fetchAuthSession(on bridgeConnection: BridgeConnection) async throws -> BridgeAuthSessionResponse {
        try await fetchAuthorized(bridgeConnection, path: "/auth/session")
    }

    func reject(_ approval: ApprovalItem, on bridgeConnection: BridgeConnection, reason: String = "rejected_by_operator") async throws {
        let payload = BridgeRejectRequest(reason: reason)
        try await sendAuthorized(
            bridgeConnection,
            path: "/approvals/\(approval.id)/reject",
            method: "POST",
            body: payload
        )
    }

    func pause(task: TaskSummary, on bridgeConnection: BridgeConnection) async throws {
        try await sendTaskControl(path: "/lobsters/\(task.lobsterID)/pause", on: bridgeConnection)
    }

    func resume(task: TaskSummary, on bridgeConnection: BridgeConnection) async throws {
        try await sendTaskControl(path: "/lobsters/\(task.lobsterID)/resume", on: bridgeConnection)
    }

    func terminate(task: TaskSummary, on bridgeConnection: BridgeConnection) async throws {
        try await sendTaskControl(path: "/lobsters/\(task.lobsterID)/terminate", on: bridgeConnection)
    }

    func retry(task: TaskSummary, on bridgeConnection: BridgeConnection) async throws {
        try await sendTaskControl(path: "/tasks/\(task.id)/retry", on: bridgeConnection)
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
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw mapNetworkError(error)
        }
    }

    private func sendAuthorized<T: Encodable>(_ bridgeConnection: BridgeConnection, path: String, method: String, body: T) async throws {
        var request = try makeRequest(baseURL: bridgeConnection.baseURL, path: path)
        request.httpMethod = method
        request.addValue("Bearer \(bridgeConnection.token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
        } catch {
            throw mapNetworkError(error)
        }
    }

    private func sendTaskControl(path: String, on bridgeConnection: BridgeConnection) async throws {
        var request = try makeRequest(baseURL: bridgeConnection.baseURL, path: path)
        request.httpMethod = "POST"
        request.addValue("Bearer \(bridgeConnection.token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
        } catch {
            throw mapNetworkError(error)
        }
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
            throw ConnectorError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let serverError = try? JSONDecoder().decode(BridgeErrorResponse.self, from: data) {
                if http.statusCode == 401 || serverError.error.code == "unauthorized" {
                    throw ConnectorError.unauthorized(serverError.diagnostics)
                }
                if http.statusCode == 410 || serverError.error.code == "pair_session_expired" || serverError.error.code == "pair_code_invalid" {
                    throw ConnectorError.pairSessionExpired
                }
                throw ConnectorError.server(code: serverError.error.code, message: serverError.error.message)
            }

            if http.statusCode == 401 {
                throw ConnectorError.unauthorized(nil)
            }
            if http.statusCode == 410 {
                throw ConnectorError.pairSessionExpired
            }
            throw ConnectorError.server(code: "http_\(http.statusCode)", message: "Bridge 返回了错误状态：\(http.statusCode)")
        }
    }

    private func mapNetworkError(_ error: Error) -> Error {
        if let connectorError = error as? ConnectorError {
            return connectorError
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut, .dnsLookupFailed, .resourceUnavailable, .internationalRoamingOff, .callIsActive, .dataNotAllowed:
                return ConnectorError.bridgeUnavailable
            default:
                return urlError
            }
        }

        return error
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

private struct BridgeErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
    }

    let error: ErrorBody
    let diagnostics: AuthDiagnostics?
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

struct RuntimeStatusDiagnostics: Decodable, Equatable {
    struct SupervisorAck: Decodable, Equatable {
        let source: String?
        let status: String
        let target: String?
        let requestID: String?
        let requestedAt: String?
        let requestedBy: String?
        let result: String?
        let evidence: String?
        let updatedAt: String?

        private enum CodingKeys: String, CodingKey {
            case source, status, target, result, evidence
            case requestID = "request_id"
            case requestedAt = "requested_at"
            case requestedBy = "requested_by"
            case updatedAt = "updated_at"
        }
    }

    let status: String
    let source: String?
    let lastRestartRequestedAt: String?
    let lastRestartRequestID: String?
    let lastRestartRequestedBy: String?
    let lastRestartHandledAt: String?
    let restartExecutionState: String?
    let restartResult: String?
    let restartEvidence: String?
    let supervisorAck: SupervisorAck?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case status, source, error
        case lastRestartRequestedAt = "last_restart_requested_at"
        case lastRestartRequestID = "last_restart_request_id"
        case lastRestartRequestedBy = "last_restart_requested_by"
        case lastRestartHandledAt = "last_restart_handled_at"
        case restartExecutionState = "restart_execution_state"
        case restartResult = "restart_result"
        case restartEvidence = "restart_evidence"
        case supervisorAck = "supervisor_ack"
    }
}

struct AuthDiagnostics: Decodable, Equatable {
    struct PairSession: Decodable, Equatable {
        let pairingID: String?
        let state: String
        let expiresAt: String?
        let bridgeURL: String?

        private enum CodingKeys: String, CodingKey {
            case state
            case pairingID = "pairing_id"
            case expiresAt = "expires_at"
            case bridgeURL = "bridge_url"
        }
    }

    struct BridgeDiagnostics: Decodable, Equatable {
        let stateSource: String?
        let activeLeases: Int?
        let runtimeStatus: RuntimeStatusDiagnostics?

        private enum CodingKeys: String, CodingKey {
            case stateSource = "state_source"
            case activeLeases = "active_leases"
            case runtimeStatus = "runtime_status"
        }
    }

    let authState: String
    let tokenPresent: Bool?
    let tokenPreview: String?
    let tokenCreatedAt: String?
    let tokenRevokedAt: String?
    let client: BridgeNodeClientInfo?
    let pairSession: PairSession
    let bridge: BridgeDiagnostics

    private enum CodingKeys: String, CodingKey {
        case authState = "auth_state"
        case tokenPresent = "token_present"
        case tokenPreview = "token_preview"
        case tokenCreatedAt = "token_created_at"
        case tokenRevokedAt = "token_revoked_at"
        case client
        case pairSession = "pair_session"
        case bridge
    }
}

struct BridgeNodeClientInfo: Decodable, Equatable {
    let deviceName: String?
    let clientName: String?
    let clientVersion: String?

    private enum CodingKeys: String, CodingKey {
        case deviceName = "device_name"
        case clientName = "client_name"
        case clientVersion = "client_version"
    }
}

struct BridgeAuthSessionResponse: Decodable {
    struct Session: Decodable {
        let tokenPreview: String?
        let createdAt: String?
        let revokedAt: String?
        let authState: String?
        let client: BridgeNodeClientInfo?

        private enum CodingKeys: String, CodingKey {
            case tokenPreview = "token_preview"
            case createdAt = "created_at"
            case revokedAt = "revoked_at"
            case authState = "auth_state"
            case client
        }
    }

    let node: BridgeNodeInfo
    let session: Session
    let diagnostics: AuthDiagnostics
}

struct BridgeDeviceInfo: Decodable {
    let id: String
    let name: String
    let platform: String
    let permissionProfile: String?
    let supportedCapabilityKinds: [String]?
    let supportedCommandAliases: [CommandAliasOption]?
    let activeCapabilityLeases: [CapabilityLease]?
    let runtimeStatus: RuntimeStatusDiagnostics?

    private enum CodingKeys: String, CodingKey {
        case id, name, platform
        case permissionProfile = "permission_profile"
        case supportedCapabilityKinds = "supported_capability_kinds"
        case supportedCommandAliases = "supported_command_aliases"
        case activeCapabilityLeases = "active_capability_leases"
        case runtimeStatus = "runtime_status"
    }
}

struct CapabilityLeaseListResponse: Decodable {
    let items: [CapabilityLease]
    let runtimeStatus: RuntimeStatusDiagnostics?

    private enum CodingKeys: String, CodingKey {
        case items
        case runtimeStatus = "runtime_status"
    }
}

private struct BridgeApproveRequest: Encodable {
    let grantedScope: String
    let durationMinutes: Int
    let capabilityKind: String
    let commandAlias: String?
    let restartAfterGrant: Bool

    private enum CodingKeys: String, CodingKey {
        case grantedScope = "granted_scope"
        case durationMinutes = "duration_minutes"
        case capabilityKind = "capability_kind"
        case commandAlias = "command_alias"
        case restartAfterGrant = "restart_after_grant"
    }
}

private struct BridgeRejectRequest: Encodable {
    let reason: String
}
