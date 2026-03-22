import SwiftUI

struct TaskDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("客户报告生成")
                    .font(.title.bold())
                ProgressView(value: 0.72)
                Text("当前步骤：CRM 导出")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("当前卡点")
                        .font(.headline)
                    Text("任务正在等待 CRM 导出权限批准。建议授权客户组 A，时效 30 分钟。")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                HStack {
                    Button("批准") {}
                        .buttonStyle(.borderedProminent)
                    Button("拒绝") {}
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
