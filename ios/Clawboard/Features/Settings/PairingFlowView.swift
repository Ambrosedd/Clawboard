import SwiftUI
import UIKit

private let skillBootstrapURL = "https://raw.githubusercontent.com/Ambrosedd/clawboard-install/main/bootstrap-clawboard-bridge.sh"
private let skillInstallCommand = "curl -fsSL https://raw.githubusercontent.com/Ambrosedd/clawboard-install/main/bootstrap-clawboard-bridge.sh | bash"
private let skillFollowupCommands = "cd ~/.clawboard/skills/clawboard-bridge\nbash scripts/start-bridge.sh\nbash scripts/show-connection.sh"
private let skillInstallMessage = "请在你的环境执行下面这条命令安装 Clawboard skill：\n\ncurl -fsSL https://raw.githubusercontent.com/Ambrosedd/clawboard-install/main/bootstrap-clawboard-bridge.sh | bash\n\n安装完成后继续执行：\n\ncd ~/.clawboard/skills/clawboard-bridge\nbash scripts/start-bridge.sh\nbash scripts/show-connection.sh\n\n然后把输出的连接串发回给我。"

private extension BridgePairSession {
    func pairingLink(baseURL: String) -> String {
        let encodedURL = baseURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? baseURL
        let encodedCode = pairCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? pairCode
        return "clawboard://pair?code=\(encodedCode)&url=\(encodedURL)"
    }
}

struct PairingFlowView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bridgeAddress = "http://127.0.0.1:8787"
    @State private var pairingCode = ""
    @State private var connectionText = ""
    @State private var isPairing = false
    @State private var localError: String?
    @State private var sessionPreview: BridgePairSession?
    @State private var showAdvancedOptions = false
    @State private var hasAutofilledFromClipboard = false

    var body: some View {
        Form {
            Section("添加龙虾") {
                Text("复制服务器给你的连接串后，回到这里直接连接。App 会自动读取并拆出配对信息。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("粘贴连接信息 / 配对串 / 二维码内容", text: $connectionText, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(2...4)

                if let payload = BridgePairingPayload.parse(from: connectionText) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已识别连接信息")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.success)
                        Text("地址：\(payload.baseURL)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("配对码：\(payload.pairCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(isPairing ? "正在连接…" : "连接这台龙虾") {
                    Task { await pair() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPairing || !canAttemptPair)
            }

            Section("先让龙虾安装这个 skill") {
                Text("把下面的一键安装命令复制给你的龙虾执行。装好后，再让龙虾运行 start-bridge.sh 和 show-connection.sh，把连接串发回手机。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("下载链接")
                        .font(.caption.weight(.semibold))
                    Text(skillBootstrapURL)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Button("复制下载链接") {
                        UIPasteboard.general.string = skillBootstrapURL
                        viewModel.toastMessage = "已复制下载链接"
                    }

                    Text("一键安装命令")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 8)
                    Text(skillInstallCommand)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Button("复制安装命令") {
                        UIPasteboard.general.string = skillInstallCommand
                        viewModel.toastMessage = "已复制安装命令"
                    }

                    Text("安装后的后续命令")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 8)
                    Text(skillFollowupCommands)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Button("复制后续命令") {
                        UIPasteboard.general.string = skillFollowupCommands
                        viewModel.toastMessage = "已复制后续命令"
                    }

                    Text("可直接转发给龙虾的话术")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 8)
                    Text(skillInstallMessage)
                        .font(.caption)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Button("复制完整安装说明") {
                        UIPasteboard.general.string = skillInstallMessage
                        viewModel.toastMessage = "已复制完整安装说明"
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("1. 把安装命令发给龙虾执行", systemImage: "1.circle")
                    Label("2. 让龙虾运行 start-bridge.sh 和 show-connection.sh", systemImage: "2.circle")
                    Label("3. 把返回的连接串粘贴到这里完成连接", systemImage: "3.circle")
                }
                .font(.subheadline)
            }

            Section {
                DisclosureGroup("高级连接选项", isExpanded: $showAdvancedOptions) {
                    TextField("Bridge 地址", text: $bridgeAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    TextField("手动输入配对码（仅兜底）", text: $pairingCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

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
                            Text("建议直接分享这段连接串给手机：\n\(sessionPreview.pairingLink ?? sessionPreview.pairingLink(baseURL: sessionPreview.bridgeURL ?? bridgeAddress))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Section("说明") {
                Text("默认情况下，你不需要理解 Bridge、Connector 或 Sidecar。它们是内部实现。你只需要：复制安装命令给龙虾、让龙虾回传连接串、在 App 里连接。")
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
        .onAppear {
            autofillFromClipboardIfNeeded()
        }
    }

    private var canAttemptPair: Bool {
        if BridgePairingPayload.parse(from: connectionText) != nil { return true }
        return !pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func autofillFromClipboardIfNeeded() {
        guard !hasAutofilledFromClipboard else { return }
        hasAutofilledFromClipboard = true
        guard connectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              BridgePairingPayload.parse(from: pasted) != nil else { return }
        connectionText = pasted
    }

    private func loadPairSession() async {
        isPairing = true
        localError = nil
        defer { isPairing = false }

        do {
            sessionPreview = try await ConnectorClient().fetchPairSession(baseURL: bridgeAddress)
            if let sessionPreview {
                if pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pairingCode = sessionPreview.pairCode
                }
                if let bridgeURL = sessionPreview.bridgeURL, !bridgeURL.isEmpty {
                    bridgeAddress = bridgeURL
                }
                connectionText = sessionPreview.pairingLink ?? sessionPreview.pairingLink(baseURL: sessionPreview.bridgeURL ?? bridgeAddress)
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
            if let payload = BridgePairingPayload.parse(from: connectionText) {
                bridgeAddress = payload.baseURL
                pairingCode = payload.pairCode
                try await viewModel.pairWithBridge(payload: payload)
            } else {
                try await viewModel.pairWithBridge(baseURL: bridgeAddress, pairCode: pairingCode)
            }
            dismiss()
        } catch {
            localError = error.localizedDescription
        }
    }
}
