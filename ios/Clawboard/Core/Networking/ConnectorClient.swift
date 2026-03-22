import Foundation

final class ConnectorClient {
    func fetchLobsters() async throws -> [LobsterSummary] {
        return [
            LobsterSummary(
                id: "lobster-1",
                name: "分析龙虾 A-01",
                status: "busy",
                taskTitle: "客户报告生成",
                lastActiveAt: "1 分钟前",
                riskLevel: "medium",
                nodeName: "MacBook-Pro"
            )
        ]
    }
}
