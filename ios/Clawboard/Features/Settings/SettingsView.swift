import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("演示模式") {
                    Picker("场景", selection: $viewModel.selectedScenario) {
                        ForEach(DemoScenario.allCases) { scenario in
                            Text(scenario.title).tag(scenario)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: viewModel.selectedScenario) { _, newValue in
                        viewModel.changeScenario(newValue)
                    }

                    Text(viewModel.selectedScenario.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("连接") {
                    NavigationLink("扫码配对") {
                        PairingFlowView()
                    }
                    Label("节点管理", systemImage: "desktopcomputer")
                }

                Section("节点健康") {
                    if viewModel.nodes.isEmpty {
                        Text("当前没有节点数据")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.nodes) { node in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(node.name)
                                    Text(node.latencyText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(text: node.status, tone: node.statusTone)
                            }
                        }
                    }
                }

                Section("安全") {
                    Label("配对 Token", systemImage: "key")
                    Label("权限边界说明", systemImage: "lock.shield")
                }
            }
            .navigationTitle("设置")
        }
    }
}
