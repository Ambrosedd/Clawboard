# Clawboard iOS Demo 结构说明

## 当前目标
把 iOS 目录从“页面占位”推进到“可演示 Demo 骨架”。

当前已经补齐：
- Xcode 工程文件
- App 入口与 Tab 结构
- Mock 数据层
- AppViewModel
- Dashboard / 龙虾 / 任务 / 审批 / 设置 五个一级页面
- LobsterDetailView
- ApprovalDetailView
- PairingFlowView

---

## 目录说明

### App/
- `ClawboardApp.swift`：应用入口
- `RootTabView.swift`：底部 Tab 结构与全局 ViewModel 注入

### Core/Models/
- `AppModels.swift`：共享数据模型定义

### Core/Networking/
- `ConnectorClient.swift`：后续真实 API 的接入入口
- `MockData.swift`：当前 Demo 使用的模拟数据

### Core/ViewModels/
- `AppViewModel.swift`：统一加载和持有页面数据

### Features/
- `Dashboard/`：首页总览
- `Lobsters/`：龙虾列表 + 详情
- `Tasks/`：任务列表 + 详情
- `Approvals/`：审批列表 + 详情
- `Settings/`：设置页 + 配对流程

---

## 当前 Demo 能展示的内容
- 首页看到计数、提醒、状态卡片
- 从龙虾列表进入龙虾详情
- 从任务列表进入任务详情
- 从审批列表进入审批详情
- 从设置页进入配对流程
- 所有数据来自统一 MockData

---

## 下一步建议

### 1. UI 继续贴近原型
- 补品牌色
- 补卡片组件
- 补状态标签组件
- 统一页面视觉层级

### 2. 增加交互状态
- 审批后更新列表
- 任务控制按钮反馈
- 配对后节点状态刷新

### 3. 接真实 Connector
- 把 `ConnectorClient` 从 Mock 切到 HTTP 请求
- 增加 token 存储
- 增加错误与加载态
