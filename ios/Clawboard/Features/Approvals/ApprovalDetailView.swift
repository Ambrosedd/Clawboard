import SwiftUI

struct ApprovalDetailView: View {
    let approval: ApprovalItem
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var grantedScope = ""
    @State private var durationMinutes = 30
    @State private var capabilityKind: TemporaryCapabilityKind = .directoryAccess
    @State private var selectedCommandAlias = ""
    @State private var restartAfterGrant = true

    var body: some View {
        Form {
            Section("审批信息") {
                LabeledContent("标题", value: approval.title)
                LabeledContent("来源", value: approval.lobsterName)
                LabeledContent("原因", value: approval.reason)
                LabeledContent("范围", value: approval.scope)
                LabeledContent("时效", value: approval.expiresAt)
                HStack {
                    Text("风险")
                    Spacer()
                    StatusBadge(text: approval.riskLevel, tone: approval.riskTone)
                }
            }

            Section("处理说明") {
                TextField("可选备注", text: $note, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section("临时授权") {
                Picker("授权类型", selection: $capabilityKind) {
                    ForEach(TemporaryCapabilityKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                if capabilityKind == .directoryAccess {
                    TextField("允许访问的目录", text: $grantedScope)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    if viewModel.supportedCommandAliases.isEmpty {
                        Text("当前 Bridge 没有公开白名单命令，暂时无法授予命令权限。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("允许执行的命令", selection: $selectedCommandAlias) {
                            ForEach(viewModel.supportedCommandAliases) { alias in
                                Text("\(alias.title)（\(alias.commandPreview)）").tag(alias.id)
                            }
                        }
                    }
                }

                Stepper("授权时长：\(durationMinutes) 分钟", value: $durationMinutes, in: 5...120, step: 5)
                Toggle("授权后自动重启龙虾", isOn: $restartAfterGrant)

                if !viewModel.activeCapabilityLeases.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前生效中的临时授权")
                            .font(.caption.weight(.semibold))
                        ForEach(viewModel.activeCapabilityLeases.prefix(3)) { lease in
                            Text("• \(lease.grantedScope) · 到期时间 \(lease.expiresAt)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("批准并临时授权") {
                    Task {
                        await viewModel.approve(
                            approval,
                            grantedScope: capabilityKind == .directoryAccess ? (grantedScope.isEmpty ? approval.scope : grantedScope) : approval.scope,
                            durationMinutes: durationMinutes,
                            capabilityKind: capabilityKind,
                            commandAlias: capabilityKind == .commandAlias ? selectedCommandAlias : nil,
                            restartAfterGrant: restartAfterGrant
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(capabilityKind == .commandAlias && selectedCommandAlias.isEmpty)

                Button("仅重启龙虾") {
                    Task {
                        await viewModel.restartLobster(approval.lobsterID)
                        dismiss()
                    }
                }

                Button("拒绝", role: .destructive) {
                    Task {
                        await viewModel.reject(approval)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("审批详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            grantedScope = approval.scope
            if selectedCommandAlias.isEmpty {
                selectedCommandAlias = viewModel.supportedCommandAliases.first?.id ?? ""
            }
        }
    }
}
