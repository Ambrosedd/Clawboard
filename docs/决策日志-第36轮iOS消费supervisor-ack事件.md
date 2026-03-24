# 决策日志 - 第36轮：iOS 轻量消费 supervisor ack SSE 事件

## 背景

第 35 轮之后，connector 已经会把 `supervisor ack` 变化主动推送到 SSE，但 iOS 侧当时还没有显式消费这类事件。

这意味着：

- 事件流里已经有 `runtime.restart.ack.updated`
- 但 App 仍主要依赖通用 refresh 路径来看到变化

## 本轮目标

让 iOS 在收到 `runtime.restart.ack.updated` 时，先做一层轻量事件消费：

1. 立即更新 runtime 摘要文案
2. 按节流策略刷新 capability / auth/runtime metadata
3. 避免每个 ack 事件都触发整页全量 refresh

## 本轮实现

### 1. `handleBridgeEvent(_:)` 显式识别 ack 事件

新增分支：

- `runtime.restart.ack.updated`

### 2. 轻量更新 `runtimeStatusSummary`

iOS 会从事件 payload 里直接提取：

- `status`
- `target`
- `result`
- `request_id`

并立刻更新成用户可读摘要，例如：

- `已向宿主提交重启请求`
- `宿主已确认接单`
- `宿主已回填完成结果`
- `宿主执行失败`

### 3. 节流刷新 metadata

收到 ack 事件后，不直接整页 refresh，而是：

- 用一个短时间窗口节流
- 只触发 `refreshCapabilityMetadata()`

这样可以更快更新 settings 里的 runtime/auth 诊断摘要，同时避免过度请求。

## 结果

这一轮之后，restart ack 链路在 iOS 侧已经变成：

- SSE 事件来了
- runtime 摘要立刻更新
- metadata 轻刷一轮做收敛

所以体验上更接近真正实时，而不是“事件到了，但还得等全量刷新才看见”。

## 后续可继续

1. 把 ack 事件进一步映射到具体 lobster/task 卡片状态
2. 若 payload 足够稳定，可减少对 metadata 补刷的依赖
3. 为 release/debug 分别梳理更清晰的实时提示策略
