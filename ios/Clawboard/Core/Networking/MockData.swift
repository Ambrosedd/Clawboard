import Foundation

enum MockData {
    static let normalSnapshot = AppSnapshot(
        lobsters: [
            .init(id: "lobster-1", name: "分析龙虾 A-01", status: "待审批", taskTitle: "客户报告生成", lastActiveAt: "1 分钟前", riskLevel: "medium", nodeName: "MacBook-Pro"),
            .init(id: "lobster-2", name: "浏览器龙虾 B-02", status: "待审批", taskTitle: "发布前校验", lastActiveAt: "2 分钟前", riskLevel: "high", nodeName: "office-linux-1"),
            .init(id: "lobster-3", name: "代码龙虾 C-07", status: "异常", taskTitle: "回归测试失败重试中", lastActiveAt: "4 分钟前", riskLevel: "high", nodeName: "build-server")
        ],
        tasks: [
            .init(id: "task-1024", title: "客户报告生成", status: "waiting_approval", progress: 72, lobsterID: "lobster-1", currentStep: "CRM 导出"),
            .init(id: "task-1025", title: "发布前校验", status: "waiting_approval", progress: 61, lobsterID: "lobster-2", currentStep: "上传构建产物"),
            .init(id: "task-1026", title: "回归测试", status: "failed", progress: 88, lobsterID: "lobster-3", currentStep: "错误重试")
        ],
        approvals: [
            .init(id: "approval-1", taskID: "task-1024", lobsterID: "lobster-1", title: "CRM 导出权限", reason: "生成客户组 A 周报", scope: "客户组 A", riskLevel: "高风险", expiresAt: "30 分钟", lobsterName: "分析龙虾 A-01"),
            .init(id: "approval-2", taskID: "task-1025", lobsterID: "lobster-2", title: "临时上传权限", reason: "提交构建产物", scope: "release-bucket/tmp", riskLevel: "低风险", expiresAt: "15 分钟", lobsterName: "浏览器龙虾 B-02")
        ],
        alerts: [
            .init(id: "alert-1", level: "P1", title: "CRM 数据导出待确认", summary: "需要你批准敏感权限后才能继续执行", relatedTaskID: "task-1024"),
            .init(id: "alert-2", level: "P2", title: "测试失败重试过多", summary: "代码龙虾 C-07 在 10 分钟内失败 3 次", relatedTaskID: "task-1026")
        ],
        nodes: [
            .init(id: "node-1", name: "MacBook-Pro", status: "在线", latencyText: "22ms"),
            .init(id: "node-2", name: "office-linux-1", status: "延迟较高", latencyText: "268ms"),
            .init(id: "node-3", name: "build-server", status: "异常", latencyText: "timeout")
        ]
    )

    static let emptySnapshot = AppSnapshot(
        lobsters: [
            .init(id: "lobster-4", name: "值守龙虾 D-03", status: "运行中", taskTitle: "空闲待命", lastActiveAt: "刚刚", riskLevel: "low", nodeName: "家庭 Mac mini")
        ],
        tasks: [],
        approvals: [],
        alerts: [],
        nodes: [
            .init(id: "node-4", name: "家庭 Mac mini", status: "在线", latencyText: "18ms")
        ]
    )

    static let taskTimeline: [String: [TaskTimelineStep]] = [
        "task-1024": [
            .init(id: "step-1", title: "规划任务", detail: "已完成", state: "done"),
            .init(id: "step-2", title: "检索客户上下文", detail: "已完成", state: "done"),
            .init(id: "step-3", title: "CRM 导出", detail: "等待权限批准", state: "current"),
            .init(id: "step-4", title: "生成总结输出", detail: "未开始", state: "pending")
        ],
        "task-1025": [
            .init(id: "step-1", title: "校验 Release 配置", detail: "已完成", state: "done"),
            .init(id: "step-2", title: "生成构建产物", detail: "已完成", state: "done"),
            .init(id: "step-3", title: "上传临时包", detail: "等待上传权限", state: "current"),
            .init(id: "step-4", title: "通知测试同学", detail: "未开始", state: "pending")
        ],
        "task-1026": [
            .init(id: "step-1", title: "拉起回归测试", detail: "已完成", state: "done"),
            .init(id: "step-2", title: "定位失败用例", detail: "第三次重试仍失败", state: "current"),
            .init(id: "step-3", title: "生成异常摘要", detail: "等待人工确认是否继续", state: "pending")
        ]
    ]
}
