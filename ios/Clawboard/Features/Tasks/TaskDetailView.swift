import SwiftUI

struct TaskDetailView: View {
    let task: TaskSummary
    @EnvironmentObject private var viewModel: AppViewModel

    init(task: TaskSummary = MockData.tasks[0]) {
        self.task = task
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(task.title)
                    .font(.title.bold())
                ProgressView(value: Double(task.progress), total: 100)
                    .tint(AppTheme.brand)
                Text("当前步骤：\(task.currentStep)")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("时间线")
                        .font(.headline)
                    ForEach(MockData.taskTimeline) { step in
                        InfoCard {
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(color(for: step.state))
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title).font(.subheadline.bold())
                                    Text(step.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                InfoCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("当前卡点")
                                .font(.headline)
                            Spacer()
                            StatusBadge(text: task.status, tone: task.status == "waiting_approval" ? AppTheme.warning : AppTheme.brand)
                        }
                        Text("任务正在等待 CRM 导出权限批准。建议授权客户组 A，时效 30 分钟。")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button("批准") {
                        if let approval = viewModel.approvals.first {
                            viewModel.approve(approval)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("拒绝") {
                        if let approval = viewModel.approvals.first {
                            viewModel.reject(approval)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("终止", role: .destructive) {
                        viewModel.terminateTask()
                    }
                    .buttonStyle(.bordered)
                }

                Button("暂停任务") {
                    viewModel.pauseTask()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func color(for state: String) -> Color {
        switch state {
        case "done": return AppTheme.success
        case "current": return AppTheme.warning
        default: return .gray
        }
    }
}
