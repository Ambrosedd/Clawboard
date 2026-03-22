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

struct PersistedAppState: Codable, Hashable {
    let scenario: DemoScenario
    let snapshot: AppSnapshot
    let savedAt: Date
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
            return "模拟 Connector 暂时不可用，验证重试与错误提示。"
        }
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
