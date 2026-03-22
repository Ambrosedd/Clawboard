import Foundation

struct LobsterSummary: Identifiable, Codable {
    let id: String
    let name: String
    let status: String
    let taskTitle: String
    let lastActiveAt: String
    let riskLevel: String
    let nodeName: String
}

struct TaskSummary: Identifiable, Codable {
    let id: String
    let title: String
    let status: String
    let progress: Int
    let lobsterID: String
    let currentStep: String
}

struct ApprovalItem: Identifiable, Codable {
    let id: String
    let title: String
    let reason: String
    let scope: String
    let riskLevel: String
    let expiresAt: String
}

struct AlertItem: Identifiable, Codable {
    let id: String
    let level: String
    let title: String
    let summary: String
}
