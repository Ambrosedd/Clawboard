import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var lobsters: [LobsterSummary] = []
    @Published var tasks: [TaskSummary] = []
    @Published var approvals: [ApprovalItem] = []
    @Published var alerts: [AlertItem] = []
    @Published var nodes: [NodeSummary] = []

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
            print("Failed to load mock data: \(error)")
        }
    }
}
