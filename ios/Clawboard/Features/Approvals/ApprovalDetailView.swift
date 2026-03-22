import SwiftUI

struct ApprovalDetailView: View {
    let approval: ApprovalItem
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        Form {
            Section("审批信息") {
                LabeledContent("标题", value: approval.title)
                LabeledContent("来源", value: approval.lobsterName)
                LabeledContent("原因", value: approval.reason)
                LabeledContent("范围", value: approval.scope)
                LabeledContent("时效", value: approval.expiresAt)
                HStack {
                    Text("风险")
                    Spacer()
                    StatusBadge(text: approval.riskLevel, tone: approval.riskTone)
                }
            }

            Section("处理说明") {
                TextField("可选备注", text: $note, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section {
                Button("批准") {
                    viewModel.approve(approval)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("缩小范围") {
                    viewModel.toastMessage = "已记录缩小范围请求：\(approval.title)"
                    dismiss()
                }

                Button("拒绝", role: .destructive) {
                    viewModel.reject(approval)
                    dismiss()
                }
            }
        }
        .navigationTitle("审批详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
