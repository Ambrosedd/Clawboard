import SwiftUI

struct ApprovalCenterView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadPhase {
                case .idle, .loading:
                    LoadingStateView(title: "正在拉取审批项", subtitle: "等待模拟 Connector 返回权限请求。")
                case .failed(let message):
                    ErrorStateView(title: "审批中心加载失败", message: message, actionTitle: "重试") {
                        Task { await viewModel.refresh() }
                    }
                case .loaded:
                    approvalListContent
                }
            }
            .navigationTitle("审批")
            .navigationDestination(for: ApprovalItem.self) { approval in
                ApprovalDetailView(approval: approval)
            }
        }
    }

    private var approvalListContent: some View {
        List(viewModel.approvals) { approval in
            NavigationLink(value: approval) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(approval.title)
                            .font(.headline)
                        Spacer()
                        StatusBadge(text: approval.riskLevel, tone: approval.riskTone)
                    }
                    Text("\(approval.lobsterName) · \(approval.reason)")
                        .foregroundStyle(.secondary)
                    Text("范围：\(approval.scope) · 时效：\(approval.expiresAt)")
                        .font(.caption)
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
        .refreshable {
            await viewModel.refresh()
        }
    }
}
