# 决策日志 - 第29轮：runtime profile 与 restart action 骨架

## 背景

前几轮已经补到了：

- iOS 失败分流与 SSE 恢复
- connector 认证/会话/runtime 诊断面
- restart 执行证据增强

接下来需要解决的，不再只是“当前这条链能不能跑”，而是：

> 不同 Lobster/runtime 部署形态，bridge 应该如何表达能力差异，而不把自己变成任意远控通道？

也就是：
- legacy
- container
- supervised

这些 profile 未来应该有不同的 restart / capability / 状态采集映射。

## 本轮目标

先把骨架立起来，而不是一次做完全部执行器：

1. 在 permission profile 中显式声明 `runtime_profile`
2. 把 `restart_action` 做成可总结、可返回、可失败的结构化动作
3. 让 connector API 对外暴露 profile / restart action 摘要
4. 保持 bridge 窄边界，不因为支持多 profile 就引入任意远控

## 本轮实现

### 1. Permission profile 规范化

connector 现在会：
- 提供默认 profile
- 对外部 profile 做 normalize
- 补足缺省字段：
  - `runtime_profile`
  - `supports`
  - `directory_policy`
  - `command_aliases`
  - `restart_action`

### 2. restart_action 摘要化

新增 `summarizeRestartAction()`，目前识别：
- `signal_file`
- `supervisor_hint`
- `none`

设计原则：
- `signal_file` 可以实际执行（写入受限标记文件）
- `supervisor_hint` 目前只作为“应由宿主执行”的能力声明
- 未知动作不会自动执行，只返回说明

### 3. restart 请求结果结构化

`requestProfileRestart()` 不再只返回布尔值，而是返回：
- `ok`
- `action`
- `requested_at`
- `evidence`
- `request_id`
- `error`（若失败）

这样 `restartLobsterRuntime()` 可以把：
- 成功
- 不支持
- 声明型支持
- 执行失败

都明确映射到任务/龙虾状态和事件流中。

### 4. API 面同步暴露 profile 信息

`GET /device/info` 现在增加：
- `runtime_profile`
- `restart_action`

用于让 App / 调试端了解当前设备到底是哪种 profile、restart 是哪类受控路径。

## 为什么这轮只做骨架

因为如果直接把 container / supervised 执行器塞进 bridge：
- 很容易越过“窄控制面”边界
- 演变成任意宿主管理入口
- 破坏当前 skill-hosted local service 的安全假设

所以本轮刻意只做：
- profile 表达
- action 摘要
- 结构化结果
- 安全保守的执行策略

## 后续建议

下一步应该按 profile 分层继续：

1. `legacy`
   - 继续 signal file + runtime adapter 路径
2. `container`
   - 接受宿主侧受限 supervisor ack / status 文件
3. `supervised`
   - 接受 profile-specific restart result 文件或显式 ack

核心原则不变：
- 由宿主受限执行器完成动作
- bridge 只记录、请求、汇总和回传状态
- 不扩成任意远控平面
