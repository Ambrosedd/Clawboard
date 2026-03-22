import SwiftUI

struct LobsterListView: View {
    let items: [LobsterSummary] = [
        .init(id: "lobster-1", name: "分析龙虾 A-01", status: "运行中", taskTitle: "客户报告生成", lastActiveAt: "1 分钟前", riskLevel: "medium", nodeName: "MacBook-Pro"),
        .init(id: "lobster-2", name: "浏览器龙虾 B-02", status: "待审批", taskTitle: "发布前校验", lastActiveAt: "2 分钟前", riskLevel: "high", nodeName: "office-linux-1")
    ]

    var body: some View {
        NavigationStack {
            List(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name).font(.headline)
                        Spacer()
                        Text(item.status)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text(item.taskTitle)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(item.nodeName)
                        Spacer()
                        Text(item.lastActiveAt)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("龙虾")
        }
    }
}
