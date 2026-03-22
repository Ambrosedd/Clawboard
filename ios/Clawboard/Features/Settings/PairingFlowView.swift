import SwiftUI

struct PairingFlowView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bridgeAddress = "http://127.0.0.1:8787"
    @State private var pairingCode = ""
    @State private var isPairing = false
    @State private var localError: String?
    @State private var sessionPreview: BridgePairSession?
    @State private var showAdvancedOptions = false

    var body: some View {
        Form {
            Section("添加龙虾") {
                Text("先在你的服务器上安装并启用 Clawboard skill，然后把显示出来的配对码填到这里。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("输入配对码", text: $pairingCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button(isPairing ? "正在连接…" : "连接这台龙虾") {
                    Task { await pair() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPairing || pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("服务器上怎么操作？") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("1. 在龙虾环境中安装 Clawboard skill", systemImage: "1.circle")
                    Label("2. 启用移动连接，让它显示配对码 / 二维码", systemImage: "2.circle")
                    Label("3. 在手机里输入配对码，完成连接", systemImage: "3.circle")
                }
                .font(.subheadline)
            }

            Section {
                DisclosureGroup("高级连接选项", isExpanded: $showAdvancedOptions) {
                    TextField("Bridge 地址", text: $bridgeAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("读取当前配对信息") {
                        Task { await loadPairSession() }
                    }
                    .disabled(isPairing)

                    if let sessionPreview {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sessionPreview.displayName)
                                .font(.headline)
                            Text("节点：\(sessionPreview.nodeID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("过期：\(sessionPreview.expiresAt)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("说明") {
                Text("默认情况下，你不需要理解 Bridge、Connector 或 Sidecar。它们是内部实现。你只需要：安装 skill、拿到配对码、在 App 里连接。")
                    .foregroundStyle(.secondary)
            }

            if let localError {
                Section("连接失败") {
                    Text(localError)
                        .font(.caption)
                        .foregroundStyle(AppTheme.danger)
                }
            }
        }
        .navigationTitle("添加龙虾")
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
