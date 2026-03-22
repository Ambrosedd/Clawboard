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
                            Text(approval.riskLevel)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((approval.riskLevel == "高风险" ? Color.red : Color.orange).opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text("\(approval.lobsterName) · \(approval.reason)")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("审批")
            .navigationDestination(for: ApprovalItem.self) { approval in
                ApprovalDetailView(approval: approval)
            }
        }
    }
}
