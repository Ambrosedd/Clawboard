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
        .tint(AppTheme.brand)
        .environmentObject(viewModel)
        .task {
            await viewModel.load()
        }
        .overlay(alignment: .top) {
            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation {
                                viewModel.toastMessage = nil
                            }
                        }
                    }
            }
        }
    }
}
