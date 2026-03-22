import SwiftUI

struct ApprovalCenterView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.approvals) { approval in
                NavigationLink(value: approval) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(approval.title)
                                .font(.headline)
                            Spacer()
                            StatusBadge(
                                text: approval.riskLevel,
                                tone: approval.riskLevel == "高风险" ? AppTheme.danger : AppTheme.warning
                            )
                        }
                        Text("\(approval.lobsterName) · \(approval.reason)")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .overlay {
                if viewModel.approvals.isEmpty {
                    ContentUnavailableView("没有待审批项", systemImage: "checkmark.circle", description: Text("所有审批都已经处理完成。"))
                }
            }
            .navigationTitle("审批")
            .navigationDestination(for: ApprovalItem.self) { approval in
                ApprovalDetailView(approval: approval)
            }
        }
    }
}
