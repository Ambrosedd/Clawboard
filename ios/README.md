# Clawboard iOS

当前目录已经包含一个可直接用 Xcode 打开的基础工程结构：
- `Clawboard.xcodeproj`
- `Clawboard/` SwiftUI 源码
- `Clawboard/Assets.xcassets`

## 当前状态
这是一个基础可打开工程骨架，适合继续补：
- ViewModel
- API 请求层
- 配对流程
- 本地缓存
- Keychain 鉴权

## 打开方式
在 macOS + Xcode 环境中打开：
- `ios/Clawboard.xcodeproj`

## 下一步建议
1. 增加 LobsterDetailView
2. 增加 ApprovalDetailView / PairingFlowView
3. 抽离 Mock 数据层
4. 接入真实 Connector API
