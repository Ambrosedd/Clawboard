import SwiftUI

struct LobsterDetailView: View {
    let lobster: LobsterSummary
    @EnvironmentObject private var viewModel: AppViewModel

    var relatedTasks: [TaskSummary] {
        viewModel.tasks.filter { $0.lobsterID == lobster.id }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(lobster.name)
                        .font(.title3.bold())
                    Text("状态：\(lobster.status)")
                    Text("当前任务：\(lobster.taskTitle)")
                    Text("节点：\(lobster.nodeName)")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("相关任务") {
                ForEach(relatedTasks) { task in
                    NavigationLink(task.title) {
                        TaskDetailView(task: task)
                    }
                }
            }

            Section("快捷操作") {
                Button("暂停") {}
                Button("恢复") {}
                Button("终止", role: .destructive) {}
            }
        }
        .navigationTitle("龙虾详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
