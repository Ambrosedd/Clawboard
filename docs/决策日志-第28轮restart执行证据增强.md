# 决策日志 - 第28轮：restart 执行证据增强

## 背景

前几轮已经做到：

- bridge 可以发起 restart 请求
- runtime adapter 会消费 `restart-requested.flag`
- `runtime-status.json` 会回写 `last_restart_handled_at`
- 下一周期进入 `post_restart_validation`

但这还不够像“可验证的执行闭环”。

此前更像：
- 我们知道 restart 请求被 adapter 看到了
- 但对外只能证明“处理过”，不能更细地证明“处理到了哪个阶段、结果是什么、证据摘要是什么”

## 本轮目标

把 restart 状态从“handled 时间戳”升级为“带执行阶段与证据摘要的状态面”。

## 本轮改动

### 1. runtime-status.json 增加执行字段

新增：
- `restart_execution_state`
- `restart_result`
- `restart_evidence`

当前语义：
- `handled`
  - 已检测并消费 restart signal
- `validated`
  - 已进入下一轮 post-restart validation
- `restart_result=success`
  - 当前 adapter 路径下已完成受控处理
- `restart_evidence`
  - 用于记录当前这轮“为什么认为它被执行/校验过”

示例：
- `signal_file_consumed:manual_skill_script`
- `post_restart_validation:2026-...`

### 2. runtime-state.json 也附带 runtime 摘要

adapter 输出的标准状态快照新增：
- `runtime.status`
- `runtime.last_restart_handled_at`
- `runtime.restart_execution_state`
- `runtime.restart_result`
- `runtime.restart_evidence`

这样 bridge 外部状态快照与 `runtime-status.json` 不再完全割裂。

### 3. connector 继续暴露这些字段

由于 connector 已从 `runtime-status.json` 读取 runtime 状态，
所以 `/device/info`、`/capabilities/leases`、`/auth/session diagnostics` 等接口会自然带出更完整的 restart 状态。

### 4. 本地脚本更利于验收

- `restart-lobster.sh`
  - 写 flag 时带 `request_id`
  - 输出 `request_id` 与 `requested_at`
- `status-runtime-adapter.sh`
  - 直接解析并打印：
    - status
    - last_restart_requested_at
    - last_restart_handled_at
    - restart_execution_state
    - restart_result
    - restart_evidence

## 结果

这一轮之后，restart 的闭环从：

- “有个 handled 时间”

推进到：

- 有请求标识
- 有执行阶段
- 有结果字段
- 有证据摘要
- 有 CLI 可直接查看的状态输出

## 仍未完成

这依然不是最终真实宿主级 restart 证明。

当前证据仍属于：
- skill 内 adapter / 受控 supervisor 层面的执行证据

下一步若继续深化，应把 `restart_evidence` 从“signal file consumed”升级到更真实的执行器反馈，比如：
- supervisor ack
- worker pid 变化
- service restart result
- profile-specific action result
