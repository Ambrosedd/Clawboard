# 决策日志 - 第31轮：收尾优化（restart schema、runtime 文案、SSE refresh 去重）

## 背景

在第 30 轮把 review 中最关键的问题修掉后，还剩下三类值得继续打磨的尾巴：

1. restart signal schema 虽已基本成型，但 request_id / requested_by 还应贯穿 producer / adapter / API / App
2. iOS 设置页里的 runtime 状态仍偏开发者视角
3. SSE 重连后可能额外触发一次过近的全量 refresh

## 本轮目标

### 1. 统一 restart schema 的链路字段

让以下字段更稳定地贯穿：
- `last_restart_requested_at`
- `last_restart_request_id`
- `last_restart_requested_by`
- `last_restart_handled_at`
- `restart_execution_state`
- `restart_result`
- `restart_evidence`

### 2. 把 runtime 状态摘要从“字段直出”变成“人话”

设置页继续保留对操作者有用的信息，但尽量避免直接暴露生硬枚举值。

### 3. 给 SSE 重连后的 refresh 做轻量去重

目标不是复杂缓存，而是在刚刚全量刷新过时，不要立刻再打一次重复 refresh。

## 本轮改动

### runtime adapter

- 读取 restart flag 时同时解析：
  - `request_id`
  - `requested_by`
  - `time`
  - `reason`
- `runtime-status.json` 新增：
  - `last_restart_request_id`
  - `last_restart_requested_by`
- `runtime-state.json` 的 `runtime` 摘要也同步携带上述字段
- `restart_evidence` 现在会带 request_id / requested_by 摘要，便于串联证据链

### connector

- `readRuntimeStatus()` 继续向外暴露：
  - `last_restart_request_id`
  - `last_restart_requested_by`

### iOS

- `RuntimeStatusDiagnostics` 新增：
  - `lastRestartRequestID`
  - `lastRestartRequestedBy`
- `formatRuntimeStatus()` 改为更偏用户态表达：
  - `healthy` → `运行正常`
  - `restart_handled` → `正在处理重启`
  - `validated` → `已完成重启后校验`
  - `success` → `成功`
- 同时保留：
  - 请求来源
  - 请求号
  - 最近处理时间

### SSE reconnect 去重

- 在 `AppViewModel` 中新增最近一次全量刷新时间
- reconnect 后仅当距离上次全量 refresh 超过短阈值时，才再触发一次 `refresh()`
- 这样在“刚刷新完又因事件流恢复而重连”的情况下，可以减少一轮重复请求

## 结果

这一轮之后：

- restart 的 request_id / requested_by 证据链更完整
- 设置页的 runtime 状态更像产品而不是 raw backend dump
- SSE 重连路径更克制，减少了不必要的重复 refresh

## 仍可继续优化

- 如果后续引入更明确的 debug 面，可把 raw evidence / raw runtime values 放进 debug 详情页，而让设置页只显示产品化摘要
- SSE 未来还可以继续做更细粒度的 refresh 合并策略
