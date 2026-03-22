import SwiftUI

struct ApprovalDetailView: View {
    let approval: ApprovalItem
    @State private var note = ""

    var body: some View {
        Form {
            Section("审批信息") {
                LabeledContent("标题", value: approval.title)
                LabeledContent("来源", value: approval.lobsterName)
                LabeledContent("原因", value: approval.reason)
                LabeledContent("范围", value: approval.scope)
                LabeledContent("时效", value: approval.expiresAt)
                LabeledContent("风险", value: approval.riskLevel)
            }

            Section("处理说明") {
                TextField("可选备注", text: $note, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section {
                Button("批准") {}
                    .buttonStyle(.borderedProminent)
                Button("缩小范围") {}
                Button("拒绝", role: .destructive) {}
            }
        }
        .navigationTitle("审批详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
