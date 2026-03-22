import SwiftUI

struct LobsterListView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.lobsters) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Text(item.status)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor(item.status).opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(item.taskTitle)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(item.nodeName)
                            Spacer()
                            Text(item.lastActiveAt)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("龙虾")
            .navigationDestination(for: LobsterSummary.self) { lobster in
                LobsterDetailView(lobster: lobster)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "运行中": return .green
        case "待审批": return .orange
        case "异常": return .red
        default: return .gray
        }
    }
}
