import SwiftUI

struct LobsterDetailView: View {
    let lobster: LobsterSummary
    @EnvironmentObject private var viewModel: AppViewModel

    var currentLobster: LobsterSummary {
        viewModel.lobsters.first(where: { $0.id == lobster.id }) ?? lobster
    }

    var relatedTasks: [TaskSummary] {
        viewModel.tasks.filter { $0.lobsterID == currentLobster.id }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(currentLobster.name)
                            .font(.title3.bold())
                        Spacer()
                        StatusBadge(text: currentLobster.status, tone: currentLobster.statusTone)
                    }
                    Text("当前任务：\(currentLobster.taskTitle)")
                    Text("节点：\(currentLobster.nodeName)")
                        .foregroundStyle(.secondary)
                    Text("最近活跃：\(currentLobster.lastActiveAt)")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("相关任务") {
                if relatedTasks.isEmpty {
                    ContentUnavailableView("没有关联任务", systemImage: "tray", description: Text("这个龙虾当前处于待命状态。"))
                } else {
                    ForEach(relatedTasks) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(task.title)
                                        .font(.headline)
                                    Spacer()
                                    StatusBadge(text: task.statusLabel, tone: task.statusTone)
                                }
                                Text(task.currentStep)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section("快捷操作") {
                if let task = relatedTasks.first {
                    if task.status == "paused" {
                        Button("恢复") {
                            Task { await viewModel.resumeTask(task) }
                        }
                    } else if task.status == "failed" || task.status == "terminated" {
                        Button("重试") {
                            Task { await viewModel.retryTask(task) }
                        }
                    } else if task.status != "completed" {
                        Button("暂停") {
                            Task { await viewModel.pauseTask(task) }
                        }
                    }

                    if task.status != "terminated" && task.status != "completed" {
                        Button("终止", role: .destructive) {
                            Task { await viewModel.terminateTask(task) }
                        }
                    }
                } else {
                    Text("当前没有可操作的活跃任务")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("龙虾详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
