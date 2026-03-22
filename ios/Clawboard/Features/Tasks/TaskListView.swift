import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.tasks) { task in
                NavigationLink(value: task) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.headline)
                        Text("当前步骤：\(task.currentStep)")
                            .foregroundStyle(.secondary)
                        ProgressView(value: Double(task.progress), total: 100)
                        Text("进度 \(task.progress)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("任务")
            .navigationDestination(for: TaskSummary.self) { task in
                TaskDetailView(task: task)
            }
        }
    }
}
