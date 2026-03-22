import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("你的龙虾今天有点忙")
                        .font(.largeTitle.bold())

                    VStack(alignment: .leading, spacing: 8) {
                        Text("3 个事项需要优先处理")
                            .font(.headline)
                        Text("2 个待审批，1 个高优异常")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding()
            }
            .navigationTitle("首页")
        }
    }
}
