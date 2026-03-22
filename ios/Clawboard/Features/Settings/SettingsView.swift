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
                    Label("节点管理", systemImage: "desktopcomputer")
                }

                Section("节点健康") {
                    ForEach(viewModel.nodes) { node in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(node.name)
                                Text(node.latencyText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(node.status)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(backgroundColor(node.status).opacity(0.15))
                                .clipShape(Capsule())
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

    private func backgroundColor(_ status: String) -> Color {
        switch status {
        case "在线": return .green
        case "延迟较高": return .orange
        case "异常": return .red
        default: return .gray
        }
    }
}
