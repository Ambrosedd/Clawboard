# 决策日志 - 第33轮：supervisor ack 状态合流到 runtime_status

## 背景

第 32 轮已经给 `supervisor_hint` 加上了 `ack_file` 契约，但当时仍有一个明显缺口：

- bridge 会写 `ack_file`
- 本地 supervisor / container runtime 也可以回填结果
- 但 connector 对外返回的 `runtime_status` 还不会消费这份 ack

结果就是：

- 文件契约存在了
- API / App 还看不到一条完整的 `requested -> acknowledged -> completed/failed` 状态链

## 本轮目标

把 `supervisor_hint` 的 ack 结果读回 connector，并合并进：

- `runtime_status`
- `/device/info`
- auth diagnostics
- iOS 设置页摘要

## 本轮实现

### 1. connector 读取 `ack_file`

`readRuntimeStatus()` 现在会在 `restart_action.type === supervisor_hint` 且配置了 `ack_file` 时：

- 解析 ack JSON
- 生成 `supervisor_ack`
- 把以下字段尽量回填到 runtime 视图：
  - `last_restart_request_id`
  - `last_restart_requested_at`
  - `last_restart_requested_by`
  - `restart_execution_state`
  - `restart_result`
  - `restart_evidence`

### 2. 统一第一版状态枚举

当前先支持：

- `requested`
- `acknowledged`
- `completed`
- `failed`
- `missing`
- `invalid`

其中：

- `requested`：bridge 已写请求/ack 文件
- `acknowledged`：本地执行器已确认接单
- `completed`：本地执行器已完成并回填结果
- `failed`：本地执行器显式回填失败

### 3. iOS 文案同步人话化

设置页现在会把这些状态映射成：

- `已向宿主提交重启请求`
- `宿主已确认接单`
- `宿主已回填完成结果`
- `宿主执行失败`

并补充：

- `宿主回执：已收到请求 / 已确认执行 / 已回填完成 / 执行失败 / 等待回填 / 回执异常`
- `执行器：container_runtime / host_supervisor`

## 为什么这样做

这样做的意义不是“bridge 终于会管宿主了”，恰恰相反：

- bridge 仍然不直接执行宿主命令
- 它只是开始**读懂本地受控执行器的回执**

所以控制边界没有扩大，但状态闭环比上轮更真。

## 结果

这一轮之后，对于 `container` / `supervised` profile：

- bridge 不再只会说“我发了个 hint”
- App / diagnostics 可以看到第一版宿主 ack/result 状态链

这让后续真正接 container runtime / supervisor wrapper 时，只需要把本地回填动作做实，而不用再改 App-facing 契约。

## 后续仍可继续

1. 提供本地示例 ack writer / wrapper 脚本
2. 统一 `updated_at` / `completed_at` / `error_reason` 等字段
3. 让 runtime adapter 把 ack 状态也回写进 `runtime-status.json`，进一步减少 connector 即时拼装逻辑
