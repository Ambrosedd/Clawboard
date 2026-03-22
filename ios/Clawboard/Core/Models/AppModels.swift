import Foundation

struct LobsterSummary: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let status: String
    let taskTitle: String
    let lastActiveAt: String
    let riskLevel: String
    let nodeName: String
}

struct TaskSummary: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let status: String
    let progress: Int
    let lobsterID: String
    let currentStep: String
}

struct ApprovalItem: Identifiable, Codable, Hashable {
    let id: String
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
