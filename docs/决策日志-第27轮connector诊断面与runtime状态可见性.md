# 决策日志 - 第27轮：connector 诊断面与 runtime 状态可见性

## 背景

第 26 轮已经把 iOS 端做到了：

- 区分 Bridge 不可达 / 会话失效 / 配对过期
- SSE 断线重连与前后台恢复
- App 安装引导同步 Cloudflare tunnel 流程

但当 App 收到 401 或状态异常时，仍然有一个问题：

> iOS 端虽然能“分类失败”，但服务端给的上下文还不够丰富。

例如：
- token 是缺失、无效、还是已撤销？
- 当前 pair session 是否已过期？
- runtime 最近有没有处理过 restart？
- 当前 bridge 读的是 seed，还是外部 state file？

这些都应该让 App 或调试端能直接看到，而不是靠猜。

## 本轮目标

### 1. 补强认证/会话诊断面

在 connector 中补充：

- `401 unauthorized` 返回 `diagnostics`
- `GET /auth/session` 返回更完整的 session 状态
- 明确区分：
  - missing
  - invalid
  - revoked
  - active

同时把 pair session 的状态也一并返回。

### 2. 补 runtime 状态可见性

桥接层现在已经：

- 消费 capability lease
- 处理 restart signal
- 维护 runtime-status.json

所以本轮把这些状态显式暴露给：

- `/device/info`
- `/capabilities/leases`
- `/debug/diagnostics`

让 App 和本地调试都能看到：
- runtime status
- last restart requested/handled
- active leases

### 3. iOS 设置页消化这些状态

在 App 中新增：
- auth session summary
- runtime status summary

用于把“桥接可用但状态异常”的场景解释清楚。

## 改动摘要

### Connector

- 新增 `getAuthDiagnostics()`
- `401 unauthorized` 时附带 `diagnostics`
- `/auth/session` 返回：
  - auth_state
  - created_at
  - revoked_at
  - pair_session.state
  - bridge.runtime_status
- `/device/info` 与 `/capabilities/leases` 附带 `runtime_status`
- 新增 `/debug/diagnostics`
  - 本地请求可直接查看 token 摘要、runtime 状态、lease 状态、state source 状态

### iOS

- `ConnectorError.unauthorized` 改为携带 `AuthDiagnostics`
- 根据 diagnostics 进一步区分：
  - token revoked
  - pair session expired
- 新增模型：
  - `AuthDiagnostics`
  - `RuntimeStatusDiagnostics`
  - `BridgeAuthSessionResponse`
- `AppViewModel.refreshCapabilityMetadata()` 同时拉：
  - `/device/info`
  - `/capabilities/leases`
  - `/auth/session`
- 设置页显示：
  - 当前会话摘要
  - runtime 状态摘要

## 结果

这一轮之后：

- iOS 不再只知道“401 了”，而能知道更接近真实原因的上下文
- 本地 bridge 的 runtime 状态对调试者可见
- restart 与 lease 不再只是内部文件状态，而变成 App / debug 面可以消费的信息

## 后续建议

下一轮继续做两件事：

1. 把 runtime adapter 再往真实 supervisor / 宿主执行层深接一层
2. 把 restart 从“状态可见”推进到“真实执行证据更强”
