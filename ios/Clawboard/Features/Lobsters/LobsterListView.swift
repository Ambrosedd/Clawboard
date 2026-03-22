import SwiftUI

struct LobsterListView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadPhase {
                case .idle, .loading, .restoring:
                    LoadingStateView(title: "正在同步龙虾列表", subtitle: "加载代理状态、绑定节点和当前任务。")
                case .failed(let message):
                    ErrorStateView(title: "龙虾列表加载失败", message: message, actionTitle: "重试") {
                        Task { await viewModel.refresh() }
                    }
                case .loaded:
                    lobsterListContent
                }
            }
            .navigationTitle("龙虾")
            .navigationDestination(for: LobsterSummary.self) { lobster in
                LobsterDetailView(lobster: lobster)
            }
        }
    }

    private var lobsterListContent: some View {
        List(viewModel.lobsters) { item in
            NavigationLink(value: item) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.name)
                            .font(.headline)
                        Spacer()
                        StatusBadge(text: item.status, tone: item.statusTone)
                    }
                    Text(item.taskTitle)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(item.nodeName)
                        Spacer()
                        Text(item.lastActiveAt)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .overlay {
            if viewModel.lobsters.isEmpty {
                ContentUnavailableView("没有龙虾", systemImage: "square.grid.2x2", description: Text("先去设置页配对 Connector，或者切换到标准演示。"))
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
