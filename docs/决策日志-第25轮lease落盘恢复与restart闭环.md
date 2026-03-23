# 决策日志-第25轮 lease 落盘恢复与 restart 闭环

## 背景
上一轮已经补了：
- runtime state adapter
- token 持久化

但仍存在两个 P0 缺口：
1. lease 虽然在 approve 时创建，但 bridge 重启后未从文件恢复
2. restart 只是 bridge 写标记，缺少 adapter 侧“已处理 / 已校验”的闭环反馈

## 本轮实现
### 1. lease 启动恢复
- bridge 新增 `loadPersistedCapabilityLeases()`
- 启动时从 `CAPABILITY_LEASES_FILE` 恢复未过期 lease
- 并重新裁剪过期项后回写文件

这样 `/capabilities/leases` 在 bridge 重启后仍能返回有效 lease。

### 2. runtime adapter 真消费 lease / restart
adapter 现在会：
- 读取 `runtime/capability-leases.json`
- 识别有效 lease 数量、scope、kind、过期时间
- 把 lease 生效情况映射到 `runtime/runtime-state.json`
- 检测 `runtime/restart-requested.flag`
- 处理后回写 `runtime/runtime-status.json`
- 清理 restart flag
- 下一周期进入 `post_restart_validation` 状态

## 本轮验证
### 验证 1：审批后 lease 文件落地
已通过 debug approval + approve 流程验证，生成：
- `lease-approval-debug-1774290563659`
- `granted_scope=/tmp/clawboard-runtime-e2e`

### 验证 2：restart 闭环
adapter 在处理 restart 后，状态推进为：
- `current_step=post_restart_validation`
- `output_summary=last_restart_handled_at=...`
- recent_logs 中出现 `runtime_status=healthy`

### 验证 3：bridge 重启后 lease 仍可读
重启 bridge 后，再次请求 `/capabilities/leases`，仍能返回同一条有效 lease。

## 结论
控制面不再只是“创建了一个 lease 记录”，而是已经具备：
- 文件落盘
- bridge 启动恢复
- adapter 消费 lease
- restart 请求处理回执

## 仍未完成
- adapter 目前仍是 skill 内 supervisor 模拟层，不是真实业务 runtime / lobster worker
- App 端 401 提示仍需明确化
- SSE 稳定性仍未专项处理
