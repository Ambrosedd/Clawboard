import SwiftUI

struct PairingFlowView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pairingCode = "LX-2026-PAIR"
    @State private var isPaired = false

    var body: some View {
        Form {
            Section("步骤") {
                Label("在电脑或服务器上启动 Connector", systemImage: "1.circle")
                Label("扫描配对二维码或输入配对码", systemImage: "2.circle")
                Label("换取长期 token 并存入 Keychain", systemImage: "3.circle")
            }

            Section("演示配对") {
                LabeledContent("配对码", value: pairingCode)
                Button(isPaired ? "已配对成功" : "模拟完成配对") {
                    isPaired = true
                    viewModel.completePairing()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Section("说明") {
                Text("当前为 Demo 骨架，后续这里可以接入二维码扫描、节点发现和 token 保存。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("扫码配对")
        .navigationBarTitleDisplayMode(.inline)
    }
}
