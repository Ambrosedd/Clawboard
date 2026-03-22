import Foundation

final class ConnectorClient {
    func fetchLobsters() async throws -> [LobsterSummary] {
        MockData.lobsters
    }

    func fetchTasks() async throws -> [TaskSummary] {
        MockData.tasks
    }

    func fetchApprovals() async throws -> [ApprovalItem] {
        MockData.approvals
    }

    func fetchAlerts() async throws -> [AlertItem] {
        MockData.alerts
    }

    func fetchNodes() async throws -> [NodeSummary] {
        MockData.nodes
    }
}
