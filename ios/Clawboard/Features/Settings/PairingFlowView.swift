import SwiftUI
import UIKit

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

            Section("服务器上怎么操作？") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("1. 在龙虾环境中安装 Clawboard skill", systemImage: "1.circle")
                    Label("2. 启用移动连接，复制连接串或显示二维码", systemImage: "2.circle")
                    Label("3. 在手机里粘贴连接串，或直接扫码", systemImage: "3.circle")
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
                Text("默认情况下，你不需要理解 Bridge、Connector 或 Sidecar。它们是内部实现。你只需要：安装 skill、复制连接串、在 App 里连接。")
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
