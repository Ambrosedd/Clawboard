import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadPhase {
                case .idle, .loading:
                    LoadingStateView(title: "正在加载任务", subtitle: "为你聚合各个龙虾的执行进度。")
                case .failed(let message):
                    ErrorStateView(title: "任务列表不可用", message: message, actionTitle: "重试") {
                        Task { await viewModel.refresh() }
                    }
                case .loaded:
                    taskListContent
                }
            }
            .navigationTitle("任务")
            .navigationDestination(for: TaskSummary.self) { task in
                TaskDetailView(task: task)
            }
        }
    }

    private var taskListContent: some View {
        List(viewModel.tasks) { task in
            NavigationLink(value: task) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                        Spacer()
                        StatusBadge(text: task.statusLabel, tone: task.statusTone)
                    }

                    Text("当前步骤：\(task.currentStep)")
                        .foregroundStyle(.secondary)

                    ProgressView(value: Double(task.progress), total: 100)
                        .tint(task.statusTone)

                    HStack {
                        Text("进度 \(task.progress)%")
                        Spacer()
                        if let lobster = viewModel.lobsters.first(where: { $0.id == task.lobsterID }) {
                            Text(lobster.name)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .overlay {
            if viewModel.tasks.isEmpty {
                ContentUnavailableView("没有任务", systemImage: "tray", description: Text("当前没有活跃任务，可以切换到标准演示查看联动状态。"))
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
