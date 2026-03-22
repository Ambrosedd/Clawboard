# Clawboard iOS

当前目录已经包含一个可直接用 Xcode 打开的 SwiftUI Demo 工程：
- `Clawboard.xcodeproj`
- `Clawboard/` SwiftUI 源码
- `Clawboard/Assets.xcassets`

## 当前状态
目前 Demo 已覆盖：
- 首页 / 龙虾 / 任务 / 审批 / 设置 5 个主 Tab
- 集中式 `AppViewModel` 状态管理
- 标准 / 空状态 / 错误恢复 3 种演示场景
- loading / empty / error 三类页面状态
- 审批、任务、龙虾、提醒之间的基础联动
- 原生 SwiftUI 轻量组件化（无额外重依赖）

## 打开方式
在 macOS + Xcode 环境中打开：
- `ios/Clawboard.xcodeproj`

## 本轮实现取舍
1. 优先把 Demo 的状态表达和跨页面联动做真实
2. 暂不引入额外状态管理或 UI 依赖
3. 暂时仍以 Demo 场景 / Mock 数据承载演示，后续再切到真实 Connector HTTP

## 下一步建议
1. 用真实 Connector API 替换 Demo 场景数据源
2. 增加事件流订阅与更细粒度的刷新策略
3. 增加本地缓存、最近连接记忆与 Keychain 存储
4. 继续补异常诊断、重试与更完整的控制动作
