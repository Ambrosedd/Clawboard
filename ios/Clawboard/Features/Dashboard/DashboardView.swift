import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("你的龙虾今天有点忙")
                        .font(.largeTitle.bold())

                    InfoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(viewModel.approvals.count) 个事项需要优先处理")
                                .font(.headline)
                            Text("\(viewModel.approvals.count) 个待审批，\(viewModel.alerts.count) 个提醒")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        StatusBadge(text: "App First", tone: AppTheme.brand)
                            .padding(12)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        summaryCard(title: "在线龙虾", value: "\(viewModel.lobsters.count)")
                        summaryCard(title: "运行中任务", value: "\(viewModel.tasks.filter { $0.status != "failed" }.count)")
                        summaryCard(title: "待审批", value: "\(viewModel.approvals.count)")
                        summaryCard(title: "告警", value: "\(viewModel.alerts.count)")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("重点提醒")
                            .font(.headline)
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
                .padding()
            }
            .navigationTitle("首页")
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title.bold())
            }
        }
    }
}
