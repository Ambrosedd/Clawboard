import SwiftUI

struct RootTabView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("首页", systemImage: "house")
                }

            LobsterListView()
                .tabItem {
                    Label("龙虾", systemImage: "square.grid.2x2")
                }

            TaskListView()
                .tabItem {
                    Label("任务", systemImage: "list.bullet.rectangle")
                }

            ApprovalCenterView()
                .tabItem {
                    Label("审批", systemImage: "checkmark.shield")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .environmentObject(viewModel)
        .task {
            await viewModel.load()
        }
    }
}
