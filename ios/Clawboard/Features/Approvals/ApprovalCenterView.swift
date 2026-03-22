import SwiftUI

struct ApprovalCenterView: View {
    var body: some View {
        NavigationStack {
            List {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("#1024 CRM 导出权限")
                            .font(.headline)
                        Spacer()
                        Text("高风险")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text("分析龙虾 A-03 · 生成客户组 A 周报")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("审批")
        }
    }
}
