import SwiftUI

struct TaskDetailView: View {
    let task: TaskSummary
    @EnvironmentObject private var viewModel: AppViewModel

    var currentTask: TaskSummary {
        viewModel.tasks.first(where: { $0.id == task.id }) ?? task
    }

    var relatedApproval: ApprovalItem? {
        viewModel.approvals.first(where: { $0.taskID == currentTask.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(currentTask.title)
                    .font(.title.bold())

                InfoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("任务状态")
                                .font(.headline)
                            Spacer()
                            StatusBadge(text: currentTask.statusLabel, tone: currentTask.statusTone)
                        }
                        ProgressView(value: Double(currentTask.progress), total: 100)
                            .tint(currentTask.statusTone)
                        Text("当前步骤：\(currentTask.currentStep)")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("时间线")
                        .font(.headline)
                    ForEach(viewModel.timeline(for: currentTask)) { step in
                        InfoCard {
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(color(for: step.state))
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title)
                                        .font(.subheadline.bold())
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
                            StatusBadge(text: currentTask.statusLabel, tone: currentTask.statusTone)
                        }
                        Text(blockerMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if let approval = relatedApproval {
                    HStack {
                        Button("批准") {
                            Task { await viewModel.approve(approval) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("拒绝") {
                            Task { await viewModel.reject(approval) }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack {
                    if currentTask.status == "paused" {
                        Button("恢复任务") {
                            Task { await viewModel.resumeTask(currentTask) }
                        }
                        .buttonStyle(.borderedProminent)
                    } else if currentTask.status == "failed" || currentTask.status == "terminated" {
                        Button("重试任务") {
                            Task { await viewModel.retryTask(currentTask) }
                        }
                        .buttonStyle(.borderedProminent)
                    } else if currentTask.status != "completed" {
                        Button("暂停任务") {
                            Task { await viewModel.pauseTask(currentTask) }
                        }
                        .buttonStyle(.bordered)
                    }

                    if currentTask.status != "terminated" && currentTask.status != "completed" {
                        Button("终止", role: .destructive) {
                            Task { await viewModel.terminateTask(currentTask) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var blockerMessage: String {
        if let approval = relatedApproval {
            return "任务正在等待 \(approval.title)。建议授权范围：\(approval.scope)，时效 \(approval.expiresAt)。"
        }

        switch currentTask.status {
        case "running":
            return "任务正在自主推进中，当前无需人工介入。"
        case "paused":
            return "任务已暂停，保留当前上下文，等待你恢复。"
        case "failed":
            return "任务已进入异常状态，建议回看失败原因并决定是否重试。"
        case "terminated":
            return "任务已被终止，不再继续执行。"
        default:
            return "当前没有额外卡点。"
        }
    }

    private func color(for state: String) -> Color {
        switch state {
        case "done": return AppTheme.success
        case "current": return AppTheme.warning
        default: return .gray
        }
    }
}
