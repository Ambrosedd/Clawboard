import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadPhase {
                case .idle, .loading, .restoring:
                    LoadingStateView(title: "正在同步龙虾状态", subtitle: viewModel.isBridgeConnected ? "正在连接 Bridge、同步节点与任务状态。" : "模拟连接 Bridge、聚合任务与审批数据。")
                case .failed(let message):
                    ErrorStateView(title: "首页加载失败", message: message, actionTitle: "重试") {
                        Task { await viewModel.refresh() }
                    }
                case .loaded:
                    dashboardContent
                }
            }
            .navigationTitle("首页")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.loadPhase == .loading)
                }
            }
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.hasBlockingApproval ? "你的龙虾今天有点忙" : "当前环境比较平稳")
                    .font(.largeTitle.bold())

                InfoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(summaryHeadline)
                            .font(.headline)
                        Text(summarySubtitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    StatusBadge(text: viewModel.isBridgeConnected ? (viewModel.isRealtimeSyncActive ? "真实 Bridge · 实时中" : "真实 Bridge") : viewModel.selectedScenario.title, tone: AppTheme.brand)
                        .padding(12)
                }

                if let bridge = viewModel.bridgeConnectionSummary {
                    InfoCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("当前已连接 \(bridge.node.name)")
                                .font(.headline)
                            Text("通过 \(bridge.baseURL) 直接查看节点、任务、审批和告警。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCard(title: "在线龙虾", value: "\(viewModel.lobsters.count)", subtitle: viewModel.lobsters.isEmpty ? "暂无连接" : "含运行与待审批状态")
                    MetricCard(title: "活跃任务", value: "\(viewModel.activeTaskCount)", subtitle: viewModel.tasks.isEmpty ? "当前没有任务" : "异常任务已单独统计")
                    MetricCard(title: "待审批", value: "\(viewModel.approvals.count)", subtitle: viewModel.approvals.isEmpty ? "已全部清空" : "优先处理高风险项")
                    MetricCard(title: "告警", value: "\(viewModel.alerts.count)", subtitle: viewModel.alerts.isEmpty ? "暂无告警" : "需要人工关注")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("重点提醒")
                        .font(.headline)

                    if viewModel.alerts.isEmpty {
                        InfoCard {
                            Label("没有新的提醒，当前系统比较安静。", systemImage: "checkmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(viewModel.alerts) { alert in
                            InfoCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("[\(alert.level)] \(alert.title)")
                                            .font(.subheadline.bold())
                                        Spacer()
                                        StatusBadge(text: alert.level, tone: alert.level == "P1" ? AppTheme.danger : AppTheme.warning)
                                    }
                                    Text(alert.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var summaryHeadline: String {
        if viewModel.loadPhase != .loaded {
            return "正在加载中"
        }
        if viewModel.approvals.isEmpty && viewModel.alerts.isEmpty {
            return "当前没有需要立刻处理的事项"
        }
        return "\(viewModel.approvals.count) 个事项需要优先处理"
    }

    private var summarySubtitle: String {
        if viewModel.isBridgeConnected, let bridge = viewModel.bridgeConnectionSummary {
            if viewModel.approvals.isEmpty && viewModel.alerts.isEmpty {
                return "已连接 \(bridge.node.name)，当前没有待处理阻塞项。"
            }
            return "已连接 \(bridge.node.name)，\(viewModel.approvals.count) 个待审批，\(viewModel.alerts.count) 个提醒"
        }

        if viewModel.approvals.isEmpty && viewModel.alerts.isEmpty {
            return "审批与告警都已清空，可以转去观察任务详情。"
        }
        return "\(viewModel.approvals.count) 个待审批，\(viewModel.alerts.count) 个提醒"
    }
}
