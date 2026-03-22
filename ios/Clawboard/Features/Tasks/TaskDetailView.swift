import SwiftUI

struct TaskDetailView: View {
    let task: TaskSummary

    init(task: TaskSummary = MockData.tasks[0]) {
        self.task = task
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(task.title)
                    .font(.title.bold())
                ProgressView(value: Double(task.progress), total: 100)
                Text("当前步骤：\(task.currentStep)")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("时间线")
                        .font(.headline)
                    ForEach(MockData.taskTimeline) { step in
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
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("当前卡点")
                        .font(.headline)
                    Text("任务正在等待 CRM 导出权限批准。建议授权客户组 A，时效 30 分钟。")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                HStack {
                    Button("批准") {}
                        .buttonStyle(.borderedProminent)
                    Button("拒绝") {}
                        .buttonStyle(.bordered)
                    Button("终止", role: .destructive) {}
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func color(for state: String) -> Color {
        switch state {
        case "done": return .green
        case "current": return .orange
        default: return .gray
        }
    }
}
