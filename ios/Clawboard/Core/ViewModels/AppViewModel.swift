import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var lobsters: [LobsterSummary] = []
    @Published var tasks: [TaskSummary] = []
    @Published var approvals: [ApprovalItem] = []
    @Published var alerts: [AlertItem] = []
    @Published var nodes: [NodeSummary] = []
    @Published var toastMessage: String?

    private let client = ConnectorClient()

    func load() async {
        do {
            async let lobsters = client.fetchLobsters()
            async let tasks = client.fetchTasks()
            async let approvals = client.fetchApprovals()
            async let alerts = client.fetchAlerts()
            async let nodes = client.fetchNodes()

            self.lobsters = try await lobsters
            self.tasks = try await tasks
            self.approvals = try await approvals
            self.alerts = try await alerts
            self.nodes = try await nodes
        } catch {
            toastMessage = "加载数据失败"
            print("Failed to load mock data: \(error)")
        }
    }

    func approve(_ approval: ApprovalItem) {
        approvals.removeAll { $0.id == approval.id }
        if let index = tasks.firstIndex(where: { $0.status == "waiting_approval" }) {
            tasks[index] = TaskSummary(
                id: tasks[index].id,
                title: tasks[index].title,
                status: "running",
                progress: min(tasks[index].progress + 12, 100),
                lobsterID: tasks[index].lobsterID,
                currentStep: "继续执行"
            )
        }
        toastMessage = "已批准：\(approval.title)"
    }

    func reject(_ approval: ApprovalItem) {
        approvals.removeAll { $0.id == approval.id }
        toastMessage = "已拒绝：\(approval.title)"
    }

    func completePairing() {
        toastMessage = "配对成功，已连接 Connector"
        if nodes.isEmpty {
            nodes = MockData.nodes
        }
    }

    func pauseTask() {
        toastMessage = "已发送暂停指令"
    }

    func terminateTask() {
        toastMessage = "已发送终止指令"
    }
}
