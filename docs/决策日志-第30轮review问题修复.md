# 决策日志 - 第30轮：review 问题修复

## 背景

在完成第 26~29 轮之后，额外做了一轮独立工程 review。

review 结论总体是正面的，但指出了几处值得立刻收口的问题：

1. `/pair/exchange` 的过期返回与 iOS 侧错误分类不完全对齐
2. `/debug/test-approval` 作为 localhost 免鉴权写接口，边界过宽
3. restart 请求链路需要继续保持 schema 一致性
4. App 安装引导里漏掉了 `start-runtime-adapter.sh`

## 本轮修复

### 1. pairing 过期契约对齐

将 `/pair/exchange` 在配对 session 过期时改为：
- HTTP `410`
- error code `pair_session_expired`

同时 iOS 端继续兼容：
- `pair_session_expired`
- `pair_code_invalid`

这样无论老返回还是新返回，都能稳定落到“配对已过期”路径。

### 2. 收紧 debug 边界

`ensureAuth()` 现在只对：
- `GET /debug/diagnostics`
- 且来自 localhost

做免鉴权放行。

其他 `/debug/*` 写接口，例如：
- `POST /debug/test-approval`

不再因为 localhost 而自动放行。

这让 debug 面回到：
- 只读诊断可以本地开放
- 写操作仍需要认证

### 3. 补回 runtime adapter 启动引导

App 的 PairingFlowView 重新把：
- `start-runtime-adapter.sh`

加入安装后的推荐命令链路中，恢复为：
1. `install-cloudflared.sh`
2. `start-runtime-adapter.sh`
3. `start-bridge.sh`
4. `start-cloudflare-tunnel.sh`
5. `show-connection.sh`

这样 richer runtime / restart / lease 状态不会在默认安装引导中丢失。

## 结果

这一轮之后：

- pairing 过期错误路径对齐
- debug 写接口边界收紧
- App 引导与实际推荐链路重新一致

## 后续

接下来还可以继续优化：
- 统一 restart signal schema 的全部生产者/消费者字段
- 将 runtime 状态文案做用户态映射
- 进一步去重 SSE reconnect 后的重复 refresh

> 已在后续收尾轮继续推进上述三项。
