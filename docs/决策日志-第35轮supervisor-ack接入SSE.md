# 决策日志 - 第35轮：supervisor ack 接入 SSE 事件流

## 背景

第 34 轮已经让 `supervisor_hint + ack_file` 在本地可演示、可验证，但还有一个体验问题：

- ack 状态变化虽然会落进文件
- connector 也能读取并暴露到 diagnostics
- 但 App 侧通常还要依赖 refresh 才能看见变化

这让它离“实时控制面”还差一小步。

## 本轮目标

把 `supervisor ack` 文件变化接入 SSE，让以下状态变化能被主动推送：

- `requested`
- `acknowledged`
- `completed`
- `failed`
- `invalid`

## 本轮实现

### 1. connector 增加 `startSupervisorAckWatcher()`

当当前 permission profile 满足：

- `restart_action.type === "supervisor_hint"`
- 且存在 `ack_file`

connector 会启动本地 watcher，监听 ack 文件所在目录。

### 2. ack 变化时发出 SSE 事件

新增事件：

- `runtime.restart.ack.updated`
- `runtime.restart.ack.invalid`

其中 `runtime.restart.ack.updated` 会带上：

- `status`
- `target`
- `request_id`
- `requested_at`
- `requested_by`
- `result`
- `evidence`
- `updated_at`
- `restart_execution_state`
- `restart_result`
- `lobster_id`
- `task_id`

### 3. 做基础去重

为了避免 watcher 启动或重复写入时反复推同一条事件，connector 会对 ack 核心字段做简单 signature 去重。

## 为什么这样做

这轮仍然没有扩大权限边界：

- bridge 不直接执行宿主命令
- bridge 只是开始“实时观察宿主回执文件的变化，并把它转成事件流”

这符合当前的产品定位：

**Bridge 是窄边界控制面，不是宿主级管理员。**

## 结果

这一轮之后，supervisor/container ack 路径第一次具备：

1. bridge 发起 restart 请求
2. 本地执行器回填 ack 文件
3. connector watcher 检测变化
4. SSE 主动推送 ack 更新
5. App 可以基于事件驱动更新，而不只靠轮询/refresh

## 后续可继续

1. iOS 侧显式消费 `runtime.restart.ack.updated` 事件并做更精准刷新
2. 用更稳定的 request_id -> lobster/task 映射替代当前启发式关联
3. 让真实 wrapper 脚本在回填 ack 时同步补充 `completed_at` / `error_reason`
