import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("连接") {
                    NavigationLink("扫码配对") {
                        PairingFlowView()
                    }

                    if let bridge = viewModel.bridgeConnection {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("已连接节点：\(bridge.node.name)")
                                .font(.headline)
                            Text("地址：\(bridge.baseURL)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("配对时间：\(bridge.pairedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("断开 Bridge 连接") {
                            viewModel.disconnectBridge()
                        }
                        .foregroundStyle(AppTheme.danger)
                    } else {
                        Text("当前未连接真实 Bridge，应用将使用本地 Demo 数据。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label("节点管理", systemImage: "desktopcomputer")
                }

                Section("演示模式") {
                    Picker("场景", selection: $viewModel.selectedScenario) {
                        ForEach(DemoScenario.allCases) { scenario in
                            Text(scenario.title).tag(scenario)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .disabled(viewModel.isBridgeConnected)
                    .onChange(of: viewModel.selectedScenario) { _, newValue in
                        viewModel.changeScenario(newValue)
                    }

                    Text(viewModel.isBridgeConnected ? "连接真实 Bridge 时，场景切换会被停用，数据以真实节点状态为准。" : viewModel.selectedScenario.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("自动推进演示状态", isOn: Binding(
                        get: { viewModel.demoAutoplayEnabled },
                        set: { viewModel.setAutoplayEnabled($0) }
                    ))
                    .disabled(viewModel.isBridgeConnected)

                    Text("开启后，任务会在标准演示场景下缓慢推进，更像系统正在运行。连接真实 Bridge 后该能力自动停用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastSavedAt = viewModel.lastSavedAt {
                        Text("最近保存：\(lastSavedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("恢复初始演示状态") {
                        viewModel.resetDemoState()
                    }
                    .foregroundStyle(AppTheme.danger)
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
