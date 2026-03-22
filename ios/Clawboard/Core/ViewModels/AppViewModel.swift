import Foundation
import SwiftUI

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

    private let client = ConnectorClient()
    private let stateStore = AppStateStore()
    private var autoplayTask: Task<Void, Never>?

    deinit {
        autoplayTask?.cancel()
    }

    var activeTaskCount: Int {
        tasks.filter { !["failed", "completed", "terminated"].contains($0.status) }.count
    }

    var hasBlockingApproval: Bool {
        approvals.contains { $0.riskLevel == "高风险" }
    }

    var currentSnapshot: AppSnapshot {
        AppSnapshot(lobsters: lobsters, tasks: tasks, approvals: approvals, alerts: alerts, nodes: nodes)
    }

    func restoreIfPossible() {
        guard let persisted = stateStore.load() else { return }
        loadPhase = .restoring
        selectedScenario = persisted.scenario
        apply(snapshot: persisted.snapshot)
        hasLoadedOnce = true
        lastSavedAt = persisted.savedAt
        loadPhase = .loaded
        startAutoplayIfNeeded()
        toastMessage = "已恢复上次演示状态"
    }

    func load(force: Bool = false) async {
        if loadPhase == .loading { return }
        if hasLoadedOnce && !force { return }
        await refresh()
    }

    func refresh() async {
        loadPhase = .loading

        do {
            let snapshot = try await client.fetchSnapshot(for: selectedScenario)
            apply(snapshot: snapshot)
            hasLoadedOnce = true
            loadPhase = .loaded
            persistCurrentState()
            startAutoplayIfNeeded()
        } catch {
            clearData()
            hasLoadedOnce = true
            loadPhase = .failed("暂时无法连接 Connector，你可以稍后重试。")
            toastMessage = "加载数据失败"
            print("Failed to load demo data: \(error)")
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

    func approve(_ approval: ApprovalItem) {
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

    func reject(_ approval: ApprovalItem) {
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
        toastMessage = "配对成功，已连接 Connector"
        if nodes.isEmpty {
            nodes = MockData.normalSnapshot.nodes
        }
        persistCurrentState()
    }

    func pauseTask(_ task: TaskSummary) {
        updateTask(id: task.id) { current in
            current.status = "paused"
            current.currentStep = "等待恢复"
        }
        syncLobster(withTaskID: task.id, statusOverride: "已暂停")
        persistCurrentState()
        toastMessage = "已暂停任务：\(task.title)"
    }

    func resumeTask(_ task: TaskSummary) {
        updateTask(id: task.id) { current in
            current.status = current.progress >= 100 ? "completed" : "running"
            current.currentStep = "继续执行"
        }
        syncLobster(withTaskID: task.id)
        persistCurrentState()
        toastMessage = "已恢复任务：\(task.title)"
    }

    func terminateTask(_ task: TaskSummary) {
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

    func resetDemoState() {
        stateStore.clear()
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
        let persisted = PersistedAppState(
            scenario: selectedScenario,
            snapshot: currentSnapshot,
            savedAt: Date(),
            autoplayEnabled: demoAutoplayEnabled
        )
        stateStore.save(persisted)
        lastSavedAt = persisted.savedAt
    }

    private func startAutoplayIfNeeded() {
        stopAutoplay()
        guard demoAutoplayEnabled, selectedScenario == .normal, loadPhase == .loaded else { return }

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

    private func advanceDemoStateIfNeeded() {
        guard selectedScenario == .normal, loadPhase == .loaded else { return }

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
        case "completed": return "运行中"
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
