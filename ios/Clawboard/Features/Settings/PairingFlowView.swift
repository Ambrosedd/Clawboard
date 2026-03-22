import SwiftUI

struct PairingFlowView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bridgeAddress = "http://127.0.0.1:8787"
    @State private var pairingCode = "LX-472911"
    @State private var isPaired = false

    var body: some View {
        Form {
            Section("步骤") {
                Label("在龙虾环境中安装并启用 Clawboard skill", systemImage: "1.circle")
                Label("skill 拉起本地 bridge，并显示配对码 / 二维码", systemImage: "2.circle")
                Label("在 App 中输入地址与配对码，完成连接", systemImage: "3.circle")
            }

            Section("连接到 Bridge") {
                TextField("Bridge 地址", text: $bridgeAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("配对码", text: $pairingCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button(isPaired ? "已配对成功" : "模拟完成配对") {
                    isPaired = true
                    viewModel.completePairing()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Text("当前先保留为桥接骨架 UI。下一步将接入 /pair/session 与 /pair/exchange，并把 token 保存到 Keychain。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("说明") {
                Text("产品上用户看到的是“安装 skill → 扫码/输入配对码 → 查看龙虾状态”，不需要理解 Connector/Sidecar 等内部概念。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("扫码配对")
        .navigationBarTitleDisplayMode(.inline)
    }
}
