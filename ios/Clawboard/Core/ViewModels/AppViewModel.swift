import Foundation
import SwiftUI

enum BridgeConnectionIssue: Equatable {
    case bridgeUnavailable
    case unauthorized
    case pairSessionExpired
    case realtimeDisconnected
    case unknown(String)

    var message: String {
        switch self {
        case .bridgeUnavailable:
            return "Bridge 当前不可达，请检查网络、Tunnel 或服务是否在线"
        case .unauthorized:
            return "当前会话已失效，请重新连接这台龙虾"
        case .pairSessionExpired:
            return "配对已过期，请重新获取连接串"
        case .realtimeDisconnected:
            return "实时同步已中断，正在尝试重连"
        case .unknown(let message):
            return message
        }
    }

    var toastMessage: String {
        switch self {
        case .bridgeUnavailable:
            return "Bridge 不可达"
        case .unauthorized:
            return "会话已失效，请重新连接"
        case .pairSessionExpired:
            return "配对已过期"
        case .realtimeDisconnected:
            return "实时同步已中断，正在重连"
        case .unknown(let message):
            return message
        }
    }
}

private enum BuildFlavor {
    #if DEBUG
    static let allowsDemoMode = true
    #else
    static let allowsDemoMode = false
    #endif
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var lobsters: [LobsterSummary] = []
    @Published private(set) var tasks: [TaskSummary] = []
    @Published private(set) var approvals: [ApprovalItem] = []
    @Published private(set) var alerts: [AlertItem] = []
    @Published private(set) var nodes: [NodeSummary] = []
    @Published var toastMessage: String?
    @Published var loadPhase: AppLoadPhase = .idle
    @Published var selectedScenario: DemoScenario = .normal
    @Published private(set) var hasLoadedOnce = false
    @Published private(set) var lastSavedAt: Date?
    @Published var demoAutoplayEnabled = true
    @Published private(set) var bridgeConnection: BridgeConnection?
    @Published private(set) var bridgeConnectionSummary: BridgeConnectionSummary?
    @Published private(set) var isRealtimeSyncActive = false
    @Published private(set) var activeCapabilityLeases: [CapabilityLease] = []
    @Published private(set) var supportedCommandAliases: [CommandAliasOption] = []
    @Published private(set) var permissionProfile: String?
    @Published private(set) var bridgeIssue: BridgeConnectionIssue?
    @Published private(set) var runtimeStatusSummary: String?
    @Published private(set) var authSessionSummary: String?

    private let client = ConnectorClient()
    private let eventStreamClient = BridgeEventStreamClient()
    private let stateStore = AppStateStore()
    private let credentialStore: BridgeCredentialStoreProtocol = BridgeCredentialStore()
    private var autoplayTask: Task<Void, Never>?
    private var eventStreamTask: Task<Void, Never>?
    private var pendingRefreshTask: Task<Void, Never>?
    private var realtimeReconnectTask: Task<Void, Never>?
    private var lastBridgeEventID: String?
    private var realtimeReconnectAttempt = 0
    private var lastFullRefreshAt: Date?
    private var lastAckRefreshAt: Date?

    deinit {
        autoplayTask?.cancel()
        eventStreamTask?.cancel()
        pendingRefreshTask?.cancel()
        realtimeReconnectTask?.cancel()
    }

    var activeTaskCount: Int {
        tasks.filter { !["failed", "completed", "terminated"].contains($0.status) }.count
    }

    var hasBlockingApproval: Bool {
        approvals.contains { $0.riskLevel == "高风险" }
    }

    var isBridgeConnected: Bool {
        bridgeConnection != nil
    }

    var currentSnapshot: AppSnapshot {
        AppSnapshot(lobsters: lobsters, tasks: tasks, approvals: approvals, alerts: alerts, nodes: nodes)
    }

    func restoreIfPossible() {
        let persisted = stateStore.load()
        let credentialRecord = credentialStore.load()

        guard persisted != nil || credentialRecord != nil else { return }

        loadPhase = .restoring

        if let persisted, BuildFlavor.allowsDemoMode {
            selectedScenario = persisted.scenario
            apply(snapshot: persisted.snapshot)
            hasLoadedOnce = true
            lastSavedAt = persisted.savedAt
            bridgeConnectionSummary = persisted.bridgeConnectionSummary
            demoAutoplayEnabled = persisted.autoplayEnabled
        } else {
            selectedScenario = .normal
            demoAutoplayEnabled = false
        }

        if let credentialRecord {
            bridgeConnection = credentialRecord.connection
            bridgeConnectionSummary = credentialRecord.summary
            selectedScenario = .normal
            bridgeIssue = nil
            startEventStreamIfNeeded()
        }

        if bridgeConnection == nil, !BuildFlavor.allowsDemoMode {
            clearData()
            hasLoadedOnce = false
            lastSavedAt = nil
        }

        loadPhase = .loaded
        startAutoplayIfNeeded()
        toastMessage = bridgeConnection == nil
            ? (BuildFlavor.allowsDemoMode ? "已恢复上次演示状态" : nil)
            : "已恢复上次 Bridge 连接状态"
    }

    func load(force: Bool = false) async {
        if loadPhase == .loading { return }
        if hasLoadedOnce && !force { return }
        await refresh()
    }

    func refresh() async {
        loadPhase = .loading
        lastFullRefreshAt = Date()
        if bridgeConnection != nil {
            bridgeIssue = nil
        }

        do {
            let snapshot = try await client.fetchSnapshot(for: selectedScenario, bridgeConnection: bridgeConnection)
            apply(snapshot: snapshot)
            hasLoadedOnce = true
            loadPhase = .loaded
            if bridgeConnection != nil {
                isRealtimeSyncActive = true
                startEventStreamIfNeeded()
                await refreshCapabilityMetadata()
            }
            persistCurrentState()
            startAutoplayIfNeeded()
        } catch {
            clearData()
            hasLoadedOnce = true
            let issue = classifyBridgeIssue(from: error)
            if bridgeConnection != nil {
                bridgeIssue = issue
                loadPhase = .failed(issue.message)
                toastMessage = issue.toastMessage
                if case .unauthorized = issue {
                    stopEventStream()
                }
            } else {
                loadPhase = .failed(BuildFlavor.allowsDemoMode ? "暂时无法连接 Bridge / Demo 数据源，你可以稍后重试。" : "暂时无法连接 Bridge，请稍后重试。")
                toastMessage = "加载数据失败"
            }
            print("Failed to load app data: \(error)")
        }
    }

    func changeScenario(_ scenario: DemoScenario) {
        selectedScenario = scenario
        hasLoadedOnce = false
        stopAutoplay()
        Task {
            await refresh()
        }
    }

    func setAutoplayEnabled(_ enabled: Bool) {
        demoAutoplayEnabled = enabled
        if enabled {
            startAutoplayIfNeeded()
        } else {
            stopAutoplay()
        }
        persistCurrentState()
    }

    func pairWithBridge(payload: BridgePairingPayload) async throws {
        try await pairWithBridge(baseURL: payload.baseURL, pairCode: payload.pairCode)
    }

    func pairWithBridge(baseURL: String, pairCode: String) async throws {
        let sanitizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPairCode = pairCode.trimmingCharacters(in: .whitespacesAndNewlines)

        bridgeIssue = nil

        let session = try await client.fetchPairSession(baseURL: sanitizedBaseURL)
        let exchange = try await client.exchangePairCode(
            baseURL: sanitizedBaseURL,
            payload: BridgePairExchangeRequest(
                pairCode: sanitizedPairCode,
                deviceName: "Clawboard iPhone",
                clientName: "Clawboard iOS",
                clientVersion: "0.1.0"
            )
        )

        let connection = BridgeConnection(
            baseURL: sanitizedBaseURL,
            token: exchange.token,
            node: exchange.node,
            pairedAt: Date()
        )

        bridgeConnection = connection
        bridgeConnectionSummary = connection.summary
        credentialStore.save(
            BridgeCredentialRecord(
                baseURL: connection.baseURL,
                token: connection.token,
                node: connection.node,
                pairedAt: connection.pairedAt
            )
        )

        selectedScenario = .normal
        hasLoadedOnce = false
        stopAutoplay()
        startEventStreamIfNeeded()
        toastMessage = "已连接 \(session.displayName)"
        persistCurrentState()
        await refresh()
    }

    func disconnectBridge() {
        Task {
            if let bridgeConnection {
                do {
                    try await client.revokeCurrentToken(bridgeConnection)
                } catch {
                    print("Failed to revoke bridge token: \(error)")
                }
            }

            bridgeConnection = nil
            bridgeConnectionSummary = nil
            bridgeIssue = nil
            runtimeStatusSummary = nil
            authSessionSummary = nil
            stopEventStream()
            credentialStore.clear()
            hasLoadedOnce = false
            toastMessage = "已断开 Bridge 连接，回到本地 Demo 模式"
            persistCurrentState()
            await refresh()
        }
    }

    func approve(
        _ approval: ApprovalItem,
        grantedScope: String? = nil,
        durationMinutes: Int = 30,
        capabilityKind: TemporaryCapabilityKind = .directoryAccess,
        commandAlias: String? = nil,
        restartAfterGrant: Bool = false
    ) async {
        if let bridgeConnection {
            do {
                try await client.approve(
                    approval,
                    on: bridgeConnection,
                    grantedScope: grantedScope,
                    durationMinutes: durationMinutes,
                    capabilityKind: capabilityKind,
                    commandAlias: commandAlias,
                    restartAfterGrant: restartAfterGrant
                )
                let scopeText = capabilityKind == .commandAlias ? (commandAlias ?? "白名单命令") : (grantedScope ?? approval.scope)
                toastMessage = restartAfterGrant ? "已临时授权并重启龙虾：\(scopeText)" : "已临时授权：\(scopeText)"
                await refresh()
                await refreshCapabilityMetadata()
            } catch {
                toastMessage = "批准失败：\(error.localizedDescription)"
            }
            return
        }

        approvals.removeAll { $0.id == approval.id }
        alerts.removeAll { $0.relatedTaskID == approval.taskID }

        if let taskIndex = tasks.firstIndex(where: { $0.id == approval.taskID }) {
            tasks[taskIndex].status = "running"
            tasks[taskIndex].progress = min(tasks[taskIndex].progress + 14, 100)
            tasks[taskIndex].currentStep = nextStepDescription(for: tasks[taskIndex].title)
        }

        if let lobsterIndex = lobsters.firstIndex(where: { $0.id == approval.lobsterID }) {
            if let task = tasks.first(where: { $0.lobsterID == approval.lobsterID }) {
                lobsters[lobsterIndex].status = statusText(for: task.status)
                lobsters[lobsterIndex].taskTitle = task.title
                lobsters[lobsterIndex].lastActiveAt = "刚刚"
            }
        }

        persistCurrentState()
        toastMessage = "已批准：\(approval.title)"
    }

    func reject(_ approval: ApprovalItem) async {
        if let bridgeConnection {
            do {
                try await client.reject(approval, on: bridgeConnection)
                toastMessage = "已拒绝：\(approval.title)"
                await refresh()
            } catch {
                toastMessage = "拒绝失败：\(error.localizedDescription)"
            }
            return
        }

        approvals.removeAll { $0.id == approval.id }
        alerts.removeAll { $0.relatedTaskID == approval.taskID }

        if let taskIndex = tasks.firstIndex(where: { $0.id == approval.taskID }) {
            tasks[taskIndex].status = "failed"
            tasks[taskIndex].currentStep = "审批被拒绝，等待重新规划"
        }

        if let lobsterIndex = lobsters.firstIndex(where: { $0.id == approval.lobsterID }) {
            lobsters[lobsterIndex].status = "异常"
            lobsters[lobsterIndex].lastActiveAt = "刚刚"
        }

        persistCurrentState()
        toastMessage = "已拒绝：\(approval.title)"
    }

    func completePairing() {
        toastMessage = "配对成功，已连接 Bridge"
        if nodes.isEmpty {
            nodes = MockData.normalSnapshot.nodes
        }
        persistCurrentState()
    }

    func pauseTask(_ task: TaskSummary) async {
        if let bridgeConnection {
            do {
                try await client.pause(task: task, on: bridgeConnection)
                toastMessage = "已暂停任务：\(task.title)"
                await refresh()
            } catch {
                toastMessage = "暂停失败：\(error.localizedDescription)"
            }
            return
        }

        updateTask(id: task.id) { current in
            current.status = "paused"
            current.currentStep = "等待恢复"
        }
        syncLobster(withTaskID: task.id, statusOverride: "已暂停")
        persistCurrentState()
        toastMessage = "已暂停任务：\(task.title)"
    }

    func resumeTask(_ task: TaskSummary) async {
        if let bridgeConnection {
            do {
                try await client.resume(task: task, on: bridgeConnection)
                toastMessage = "已恢复任务：\(task.title)"
                await refresh()
            } catch {
                toastMessage = "恢复失败：\(error.localizedDescription)"
            }
            return
        }

        updateTask(id: task.id) { current in
            current.status = current.progress >= 100 ? "completed" : "running"
            current.currentStep = "继续执行"
        }
        syncLobster(withTaskID: task.id)
        persistCurrentState()
        toastMessage = "已恢复任务：\(task.title)"
    }

    func terminateTask(_ task: TaskSummary) async {
        if let bridgeConnection {
            do {
                try await client.terminate(task: task, on: bridgeConnection)
                toastMessage = "已发送终止指令：\(task.title)"
                await refresh()
            } catch {
                toastMessage = "终止失败：\(error.localizedDescription)"
            }
            return
        }

        updateTask(id: task.id) { current in
            current.status = "terminated"
            current.currentStep = "任务已终止"
        }
        approvals.removeAll { $0.taskID == task.id }
        alerts.removeAll { $0.relatedTaskID == task.id }
        syncLobster(withTaskID: task.id, statusOverride: "异常")
        persistCurrentState()
        toastMessage = "已发送终止指令：\(task.title)"
    }

    func retryTask(_ task: TaskSummary) async {
        if let bridgeConnection {
            do {
                try await client.retry(task: task, on: bridgeConnection)
                toastMessage = "已重试任务：\(task.title)"
                await refresh()
            } catch {
                toastMessage = "重试失败：\(error.localizedDescription)"
            }
            return
        }

        updateTask(id: task.id) { current in
            current.status = "running"
            current.currentStep = "重新规划并继续执行"
            current.progress = min(current.progress, 60)
        }
        syncLobster(withTaskID: task.id, statusOverride: "运行中")
        persistCurrentState()
        toastMessage = "已重试任务：\(task.title)"
    }

    func resetDemoState() {
        stateStore.clear()
        bridgeConnection = nil
        bridgeConnectionSummary = nil
        bridgeIssue = nil
        runtimeStatusSummary = nil
        authSessionSummary = nil
        stopEventStream()
        credentialStore.clear()
        selectedScenario = .normal
        hasLoadedOnce = false
        lastSavedAt = nil
        stopAutoplay()
        Task {
            await refresh()
        }
    }

    func timeline(for task: TaskSummary) -> [TaskTimelineStep] {
        if task.status == "running" {
            return [
                .init(id: "step-running-1", title: "任务恢复执行", detail: "权限已确认，继续推进", state: "done"),
                .init(id: "step-running-2", title: task.currentStep, detail: "正在处理", state: "current"),
                .init(id: "step-running-3", title: "输出结果同步", detail: "等待当前步骤完成", state: "pending")
            ]
        }

        if task.status == "paused" {
            return [
                .init(id: "step-paused-1", title: "任务进入暂停", detail: "保留当前上下文", state: "current"),
                .init(id: "step-paused-2", title: "等待人工恢复", detail: "可在任务或龙虾详情继续", state: "pending")
            ]
        }

        if task.status == "failed" || task.status == "terminated" {
            return [
                .init(id: "step-failed-1", title: "任务中断", detail: task.currentStep, state: "current"),
                .init(id: "step-failed-2", title: "等待重新规划", detail: "建议用户查看审批与日志", state: "pending")
            ]
        }

        return MockData.taskTimeline[task.id] ?? []
    }

    func relatedTask(for lobster: LobsterSummary) -> TaskSummary? {
        tasks.first { $0.lobsterID == lobster.id }
    }

    func refreshCapabilityMetadata() async {
        guard let bridgeConnection else { return }
        do {
            async let deviceInfo = client.fetchDeviceCapabilities(on: bridgeConnection)
            async let leases = client.fetchCapabilityLeases(on: bridgeConnection)
            async let authSession = client.fetchAuthSession(on: bridgeConnection)
            let (devicePayload, leasePayload, authPayload) = try await (deviceInfo, leases, authSession)
            permissionProfile = devicePayload.permissionProfile
            supportedCommandAliases = devicePayload.supportedCommandAliases ?? []
            activeCapabilityLeases = leasePayload.items
            runtimeStatusSummary = formatRuntimeStatus(devicePayload.runtimeStatus ?? leasePayload.runtimeStatus ?? authPayload.diagnostics.bridge.runtimeStatus)
            authSessionSummary = formatAuthSession(authPayload)
        } catch {
            print("Failed to refresh capability metadata: \(error)")
        }
    }

    func restartLobster(_ lobsterID: String) async {
        guard let bridgeConnection else {
            toastMessage = "Demo 模式下暂不支持真实重启"
            return
        }
        do {
            try await client.restart(lobsterID: lobsterID, on: bridgeConnection)
            toastMessage = "已发送重启指令"
            await refresh()
            await refreshCapabilityMetadata()
        } catch {
            toastMessage = "重启失败：\(error.localizedDescription)"
        }
    }

    private func apply(snapshot: AppSnapshot) {
        lobsters = snapshot.lobsters
        tasks = snapshot.tasks
        approvals = snapshot.approvals
        alerts = snapshot.alerts
        nodes = snapshot.nodes
    }

    private func clearData() {
        lobsters = []
        tasks = []
        approvals = []
        alerts = []
        nodes = []
    }

    private func persistCurrentState() {
        guard BuildFlavor.allowsDemoMode || bridgeConnectionSummary != nil else {
            lastSavedAt = nil
            return
        }
        let persisted = PersistedAppState(
            scenario: BuildFlavor.allowsDemoMode ? selectedScenario : .normal,
            snapshot: currentSnapshot,
            savedAt: Date(),
            autoplayEnabled: BuildFlavor.allowsDemoMode ? demoAutoplayEnabled : false,
            bridgeConnectionSummary: bridgeConnectionSummary
        )
        stateStore.save(persisted)
        lastSavedAt = persisted.savedAt
    }

    private func startAutoplayIfNeeded() {
        stopAutoplay()
        guard BuildFlavor.allowsDemoMode, bridgeConnection == nil, demoAutoplayEnabled, selectedScenario == .normal, loadPhase == .loaded else { return }

        autoplayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                await self?.advanceDemoStateIfNeeded()
            }
        }
    }

    private func stopAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = nil
    }

    private func startEventStreamIfNeeded() {
        stopEventStream()
        guard let bridgeConnection else { return }

        isRealtimeSyncActive = true
        bridgeIssue = nil
        eventStreamTask = eventStreamClient.stream(
            connection: bridgeConnection,
            lastEventID: lastBridgeEventID,
            onEvent: { [weak self] event in
                guard let self else { return }
                await self.handleBridgeEvent(event)
            },
            onFailure: { [weak self] failure in
                guard let self else { return }
                await self.handleEventStreamFailure(failure)
            }
        )
    }

    private func stopEventStream() {
        eventStreamTask?.cancel()
        eventStreamTask = nil
        pendingRefreshTask?.cancel()
        pendingRefreshTask = nil
        realtimeReconnectTask?.cancel()
        realtimeReconnectTask = nil
        lastBridgeEventID = nil
        realtimeReconnectAttempt = 0
        isRealtimeSyncActive = false
    }

    private func handleBridgeEvent(_ event: BridgeEvent) async {
        if let eventID = event.id, !eventID.isEmpty {
            lastBridgeEventID = eventID
        }

        switch event.name {
        case "runtime.restart.ack.updated":
            handleRuntimeAckEvent(event)
        case "bridge.started", "pair.exchanged", "auth.revoked", "lobster.status.changed", "task.progress.updated", "task.failed", "approval.resolved", "alert.created":
            scheduleRefreshFromRealtimeEvent(named: event.name)
        default:
            break
        }
    }

    private func scheduleRefreshFromRealtimeEvent(named eventName: String) {
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            await self.refreshFromRealtimeEvent(named: eventName)
        }
    }

    private func handleRuntimeAckEvent(_ event: BridgeEvent) {
        guard let data = event.envelope?.data else { return }

        let status = data["status"]?.stringValue
        let target = data["target"]?.stringValue
        let result = data["result"]?.stringValue
        let requestID = data["request_id"]?.stringValue

        var parts: [String] = ["Runtime：状态同步中"]
        switch status {
        case "requested":
            parts.append("已向宿主提交重启请求")
            parts.append("宿主回执：已收到请求")
        case "acknowledged":
            parts.append("宿主已确认接单")
            parts.append("宿主回执：已确认执行")
        case "completed":
            parts.append("宿主已回填完成结果")
            parts.append("宿主回执：已回填完成")
        case "failed":
            parts.append("宿主执行失败")
            parts.append("宿主回执：执行失败")
        default:
            if let status, !status.isEmpty {
                parts.append("宿主回执：\(status)")
            }
        }
        if let result, !result.isEmpty {
            parts.append("结果：\(result == "success" ? "成功" : (result == "error" ? "失败" : result))")
        }
        if let target, !target.isEmpty {
            parts.append("执行器：\(target)")
        }
        if let requestID, !requestID.isEmpty {
            parts.append("请求号：\(requestID)")
        }
        runtimeStatusSummary = parts.joined(separator: " · ")

        let now = Date()
        let shouldRefresh = lastAckRefreshAt.map { now.timeIntervalSince($0) > 1.5 } ?? true
        guard shouldRefresh else { return }
        lastAckRefreshAt = now
        Task { [weak self] in
            guard let self else { return }
            await self.refreshCapabilityMetadata()
        }
    }

    private func refreshFromRealtimeEvent(named eventName: String) async {
        guard bridgeConnection != nil else { return }
        do {
            let snapshot = try await client.fetchSnapshot(for: selectedScenario, bridgeConnection: bridgeConnection)
            apply(snapshot: snapshot)
            hasLoadedOnce = true
            loadPhase = .loaded
            bridgeIssue = nil
            persistCurrentState()
        } catch {
            isRealtimeSyncActive = false
            let issue = classifyBridgeIssue(from: error)
            bridgeIssue = issue
            toastMessage = issue == .realtimeDisconnected ? "实时同步暂时中断：\(eventName) 后刷新失败" : issue.toastMessage
            if issue != .unauthorized {
                scheduleRealtimeReconnect(reason: issue)
            }
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if bridgeConnection != nil {
                if eventStreamTask == nil {
                    startEventStreamIfNeeded()
                } else if !isRealtimeSyncActive {
                    scheduleRealtimeReconnect(reason: .realtimeDisconnected, resetAttempt: true)
                }
            }
        case .background:
            eventStreamTask?.cancel()
            eventStreamTask = nil
            pendingRefreshTask?.cancel()
            pendingRefreshTask = nil
            isRealtimeSyncActive = false
        default:
            break
        }
    }

    private func handleEventStreamFailure(_ failure: BridgeEventStreamFailure) async {
        guard bridgeConnection != nil else { return }

        isRealtimeSyncActive = false
        let issue: BridgeConnectionIssue
        switch failure {
        case .unauthorized:
            issue = .unauthorized
        case .bridgeUnavailable:
            issue = .bridgeUnavailable
        case .invalidResponse:
            issue = .unknown("Bridge 返回了异常响应，请稍后重试")
        case .disconnected:
            issue = .realtimeDisconnected
        }
        bridgeIssue = issue
        toastMessage = issue.toastMessage

        if issue != .unauthorized {
            scheduleRealtimeReconnect(reason: issue)
        }
    }

    private func scheduleRealtimeReconnect(reason: BridgeConnectionIssue, resetAttempt: Bool = false) {
        guard bridgeConnection != nil else { return }
        if resetAttempt {
            realtimeReconnectAttempt = 0
        }
        realtimeReconnectTask?.cancel()
        realtimeReconnectAttempt += 1
        let attempt = realtimeReconnectAttempt
        let delaySeconds = min(pow(2.0, Double(max(0, attempt - 1))), 12.0)
        realtimeReconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard let self, !Task.isCancelled, self.bridgeConnection != nil else { return }
            self.toastMessage = reason == .bridgeUnavailable ? "正在重连 Bridge 实时同步…" : "正在恢复实时同步…"
            self.startEventStreamIfNeeded()
            let shouldRefresh = self.lastFullRefreshAt.map { Date().timeIntervalSince($0) > 2.5 } ?? true
            if shouldRefresh {
                await self.refresh()
            }
        }
    }

    private func classifyBridgeIssue(from error: Error) -> BridgeConnectionIssue {
        if let connectorError = error as? ConnectorError {
            switch connectorError {
            case .unauthorized(let diagnostics):
                if diagnostics?.pairSession.state == "expired" {
                    return .pairSessionExpired
                }
                return .unauthorized
            case .pairSessionExpired:
                return .pairSessionExpired
            case .bridgeUnavailable:
                return .bridgeUnavailable
            case .invalidResponse:
                return .unknown(connectorError.userFacingMessage)
            case .server(_, let message):
                return .unknown(message)
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut, .dnsLookupFailed:
                return .bridgeUnavailable
            default:
                return .unknown(urlError.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }

    private func formatRuntimeStatus(_ runtime: RuntimeStatusDiagnostics?) -> String? {
        guard let runtime else { return nil }

        func mapRuntimeStatus(_ status: String) -> String {
            switch status {
            case "healthy": return "运行正常"
            case "restart_handled": return "正在处理重启"
            case "seed": return "演示状态源"
            case "unknown": return "状态未知"
            case "invalid": return "状态异常"
            default: return status
            }
        }

        func mapExecutionState(_ state: String?) -> String? {
            guard let state, !state.isEmpty else { return nil }
            switch state {
            case "requested": return "已向宿主提交重启请求"
            case "acknowledged": return "宿主已确认接单"
            case "completed": return "宿主已回填完成结果"
            case "failed": return "宿主执行失败"
            case "handled": return "已接收重启请求"
            case "validated": return "已完成重启后校验"
            case "seed": return "演示态"
            case "unknown": return "待确认"
            case "invalid": return "状态异常"
            default: return state
            }
        }

        func mapResult(_ result: String?) -> String? {
            guard let result, !result.isEmpty else { return nil }
            switch result {
            case "success": return "成功"
            case "error": return "失败"
            default: return result
            }
        }

        var parts: [String] = ["Runtime：\(mapRuntimeStatus(runtime.status))"]
        if let executionState = mapExecutionState(runtime.restartExecutionState) {
            parts.append(executionState)
        }
        if let result = mapResult(runtime.restartResult) {
            parts.append("结果：\(result)")
        }
        if let requestedBy = runtime.lastRestartRequestedBy, !requestedBy.isEmpty {
            parts.append("请求来源：\(requestedBy)")
        }
        if let requestID = runtime.lastRestartRequestID, !requestID.isEmpty {
            parts.append("请求号：\(requestID)")
        }
        if let ack = runtime.supervisorAck {
            switch ack.status {
            case "requested":
                parts.append("宿主回执：已收到请求")
            case "acknowledged":
                parts.append("宿主回执：已确认执行")
            case "completed":
                parts.append("宿主回执：已回填完成")
            case "failed":
                parts.append("宿主回执：执行失败")
            case "missing":
                parts.append("宿主回执：等待回填")
            case "invalid":
                parts.append("宿主回执：回执异常")
            default:
                parts.append("宿主回执：\(ack.status)")
            }
            if let target = ack.target, !target.isEmpty {
                parts.append("执行器：\(target)")
            }
        }
        if let handledAt = runtime.lastRestartHandledAt, !handledAt.isEmpty {
            parts.append("最近处理：\(handledAt)")
        }
        return parts.joined(separator: " · ")
    }

    private func formatAuthSession(_ response: BridgeAuthSessionResponse) -> String {
        let authState = response.session.authState ?? response.diagnostics.authState
        switch authState {
        case "active":
            return "当前会话有效"
        case "revoked":
            return "当前会话已撤销"
        case "invalid":
            return "当前 token 无效"
        default:
            if response.diagnostics.pairSession.state == "expired" {
                return "配对会话已过期"
            }
            return "当前会话状态未知"
        }
    }

    private func advanceDemoStateIfNeeded() {
        guard BuildFlavor.allowsDemoMode, bridgeConnection == nil, selectedScenario == .normal, loadPhase == .loaded else { return }

        if let waitingIndex = tasks.firstIndex(where: { $0.status == "waiting_approval" }) {
            let waitingTask = tasks[waitingIndex]
            if waitingTask.progress < 80 {
                tasks[waitingIndex].progress = min(waitingTask.progress + 3, 80)
                tasks[waitingIndex].currentStep = waitingTask.currentStep
                syncLobster(withTaskID: waitingTask.id)
                persistCurrentState()
                return
            }
        }

        if let runningIndex = tasks.firstIndex(where: { $0.status == "running" }) {
            tasks[runningIndex].progress = min(tasks[runningIndex].progress + 6, 100)
            if tasks[runningIndex].progress >= 100 {
                tasks[runningIndex].status = "completed"
                tasks[runningIndex].currentStep = "任务已完成"
                alerts.removeAll { $0.relatedTaskID == tasks[runningIndex].id }
                toastMessage = "任务已完成：\(tasks[runningIndex].title)"
            } else {
                tasks[runningIndex].currentStep = rollingStep(for: tasks[runningIndex])
            }
            syncLobster(withTaskID: tasks[runningIndex].id)
            persistCurrentState()
            return
        }

        if approvals.isEmpty, alerts.isEmpty, tasks.contains(where: { $0.status == "completed" }) {
            if let completedTask = tasks.first(where: { $0.status == "completed" }) {
                alerts.append(.init(id: "alert-followup-\(completedTask.id)", level: "P2", title: "结果待确认", summary: "\(completedTask.title) 已完成，建议查看输出摘要。", relatedTaskID: completedTask.id))
                persistCurrentState()
            }
        }
    }

    private func updateTask(id: String, mutate: (inout TaskSummary) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        var task = tasks[index]
        mutate(&task)
        tasks[index] = task
    }

    private func syncLobster(withTaskID taskID: String, statusOverride: String? = nil) {
        guard let task = tasks.first(where: { $0.id == taskID }),
              let lobsterIndex = lobsters.firstIndex(where: { $0.id == task.lobsterID }) else { return }

        lobsters[lobsterIndex].status = statusOverride ?? statusText(for: task.status)
        lobsters[lobsterIndex].taskTitle = task.title
        lobsters[lobsterIndex].lastActiveAt = "刚刚"
    }

    private func statusText(for taskStatus: String) -> String {
        switch taskStatus {
        case "running": return "运行中"
        case "waiting_approval": return "待审批"
        case "paused": return "已暂停"
        case "failed", "terminated": return "异常"
        case "completed": return "已完成"
        default: return "运行中"
        }
    }

    private func nextStepDescription(for title: String) -> String {
        if title.contains("客户报告") {
            return "生成总结输出"
        }
        if title.contains("发布前校验") {
            return "通知测试同学"
        }
        return "继续执行"
    }

    private func rollingStep(for task: TaskSummary) -> String {
        if task.title.contains("客户报告") {
            return task.progress > 90 ? "整理最终周报" : "生成总结输出"
        }
        if task.title.contains("发布前校验") {
            return task.progress > 90 ? "同步校验结果" : "通知测试同学"
        }
        return "继续执行"
    }
}
