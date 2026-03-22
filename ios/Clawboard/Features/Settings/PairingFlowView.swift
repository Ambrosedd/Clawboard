import SwiftUI

struct PairingFlowView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bridgeAddress = "http://127.0.0.1:8787"
    @State private var pairingCode = "LX-472911"
    @State private var isPairing = false
    @State private var localError: String?
    @State private var sessionPreview: BridgePairSession?

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
                    .keyboardType(.URL)

                TextField("配对码", text: $pairingCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button("读取配对会话") {
                    Task { await loadPairSession() }
                }
                .disabled(isPairing)

                if let sessionPreview {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sessionPreview.displayName)
                            .font(.headline)
                        Text("节点：\(sessionPreview.nodeID) · 过期：\(sessionPreview.expiresAt)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(isPairing ? "正在配对…" : "完成配对") {
                    Task { await pair() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPairing || bridgeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let localError {
                    Text(localError)
                        .font(.caption)
                        .foregroundStyle(AppTheme.danger)
                }
            }

            Section("说明") {
                Text("产品上用户看到的是“安装 skill → 扫码/输入配对码 → 查看龙虾状态”，不需要理解 Connector/Sidecar 等内部概念。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("扫码配对")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadPairSession() async {
        isPairing = true
        localError = nil
        defer { isPairing = false }

        do {
            sessionPreview = try await ConnectorClient().fetchPairSession(baseURL: bridgeAddress)
            if pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pairingCode = sessionPreview?.pairCode ?? pairingCode
            }
        } catch {
            localError = error.localizedDescription
        }
    }

    private func pair() async {
        isPairing = true
        localError = nil
        defer { isPairing = false }

        do {
            try await viewModel.pairWithBridge(baseURL: bridgeAddress, pairCode: pairingCode)
            dismiss()
        } catch {
            localError = error.localizedDescription
        }
    }
}
