# iOS 目录说明

当前 iOS 目录的目标不是只做页面壳子，而是逐步做成一个**纯 App 就能工作的单机 Demo**，并平滑演进到 **连接真实 Clawboard Bridge**。

## 当前已有能力
- SwiftUI App 工程骨架
- 首页 / 龙虾 / 任务 / 审批 / 设置
- Mock 状态联动
- 审批、任务控制、配对等交互反馈
- 演示场景切换（标准 / 空状态 / 错误恢复）
- 本地状态持久化与恢复（基于 UserDefaults + Codable）
- 轻量自动演进机制（标准演示场景下任务会缓慢推进）
- Bridge 配对骨架（`/pair/session` + `/pair/exchange`）
- Bridge 凭证存储抽象（当前用 UserDefaults 模拟 Keychain 边界，后续可切到真 Keychain）
- Bridge 断开连接时的 token revoke 调用骨架

## 当前阶段原则
1. 先让纯 App 自己工作
2. 再把 Bridge 当作后续接入层
3. 避免过早引入重型依赖或复杂持久化方案
4. 提前把凭证边界和授权边界设计对，避免后面返工

## 后续方向
- 继续打磨纯 App 单机体验
- 在真机环境接入 Keychain
- 把数据源从 Mock/本地状态逐步切到真实 Bridge
- 接入 Bridge token 生命周期管理、撤销与多设备管理
- 再逐步把 Bridge 接到真实 Lobster runtime
