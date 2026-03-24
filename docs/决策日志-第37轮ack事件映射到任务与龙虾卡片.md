# 决策日志 - 第37轮：ack 事件映射到任务与龙虾卡片

## 背景

第 36 轮之后，iOS 已经会消费 `runtime.restart.ack.updated`，但当时主要更新的是 settings 里的 runtime 摘要。

这意味着：

- 用户能在设置页看到 ack 状态变化
- 但任务列表、龙虾列表未必会立刻体现同一条状态链

## 本轮目标

让 ack 事件在 iOS 侧不仅影响 runtime 摘要，也能轻量映射到：

- 任务列表
- 龙虾列表

从而让用户在主界面上更快感知“请求已发出 / 宿主已确认 / 已完成 / 已失败”。

## 本轮实现

### 1. `handleRuntimeAckEvent(_:)` 读取 `lobster_id` / `task_id`

connector 的 SSE 事件已携带：

- `lobster_id`
- `task_id`

本轮 iOS 显式读取它们。

### 2. 新增 `applyRuntimeAckEvent(...)`

收到 ack 事件后，会先针对对应 task / lobster 做一层轻量即时映射：

#### Task
- `requested` → 当前步骤改为“已向宿主执行器提交重启请求”
- `acknowledged` → 状态保持/回到 `running`，步骤改为“宿主已确认执行重启”
- `completed` → 步骤改为“宿主已完成重启并恢复执行”
- `failed` → 状态置为 `failed`，步骤改为“宿主重启失败，等待处理”

#### Lobster
- `requested` → 更新时间为“刚刚”
- `acknowledged` → 标记为运行中
- `completed` → 标记为运行中，并补一条已完成重启的提示
- `failed` → 标记为异常，并提示检查执行器回执

## 为什么这样做

这是一个有意保持保守的 UI 映射：

- 不试图在前端凭空重建完整运行时状态机
- 只是把 ack 事件映射成更接近用户感知的即时卡片更新

后续真正的权威状态，仍会由 refresh / metadata 补刷收敛。

## 结果

这一轮之后，restart ack 链路在 iOS 主界面上的体验变成：

- 设置页 runtime 摘要会变
- 任务卡片也会变
- 龙虾卡片也会变

用户不用切去设置页，主列表里就能更快看到 restart 进度。

## 后续可继续

1. 让 task/lobster 的映射文案进一步与真实状态机统一
2. 当 connector 侧有更稳定的任务/龙虾关联方式时，替换当前直接 `task_id/lobster_id` 映射
3. 对完成/失败场景补更细的 toast 或局部动画反馈
