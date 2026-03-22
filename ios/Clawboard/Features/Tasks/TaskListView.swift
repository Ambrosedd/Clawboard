import SwiftUI

struct TaskListView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("客户报告生成") {
                    TaskDetailView()
                }
            }
            .navigationTitle("任务")
        }
    }
}
