# 决策日志 - 第26轮：iOS 错误分流、SSE 重连与安装引导对齐

## 背景

前两轮已经补上：

- runtime state adapter 接入 `/tasks` / `/lobsters`
- token 持久化
- capability lease 落盘与恢复
- restart 请求被 adapter 消费并回写状态
- Cloudflare tunnel 配对与 HTTPS base URL 优先级

因此当前主痛点从“链路是否存在”切换成“用户是否感知为可用”：

1. iOS 端把不同失败都落成“加载失败”
2. SSE 事件流能连但不够稳，缺前后台恢复与重连 backoff
3. App 内安装说明还没有完全与 Cloudflare 新链路对齐

## 本轮目标

### 1. 错误分流产品化

让 App 至少能区分：

- Bridge 不可达
- 当前 token / 会话失效（401）
- 配对会话过期
- 未知服务端异常

目标不是做复杂诊断，而是避免用户把所有问题都理解成“Bridge 挂了”。

### 2. SSE 稳定性增强

在现有事件流基础上补：

- 断线后的自动重连
- capped exponential backoff
- App 回到前台后恢复订阅
- 避免重复建立 stream

目标是把“能收到事件”推进到“通常能稳定持续收到事件”。

### 3. 安装引导对齐 Cloudflare 新链路

将 App 安装说明统一到：

1. `install-cloudflared.sh`
2. `start-bridge.sh`
3. `start-cloudflare-tunnel.sh`
4. `show-connection.sh`

并强调最终应回传 HTTPS 连接串。

## 改动摘要

### iOS 网络层

- 在 `ConnectorClient` 中引入显式错误分类：
  - `unauthorized`
  - `pairSessionExpired`
  - `bridgeUnavailable`
  - `invalidResponse`
  - `server(code,message)`
- 将常见 `URLError` 映射为 bridge 不可达类错误
- 为 pairing / authorized fetch / task control / revoke 等路径统一映射 user-facing message

### iOS 状态层

- 在 `AppViewModel` 中新增 `BridgeConnectionIssue`
- `refresh()` 失败时不再统一显示“加载失败”，而是按问题种类给出提示
- 设置页会展示当前 bridge issue

### SSE

- `BridgeEventStreamClient` 支持 `onFailure`
- ViewModel 在事件流断开时：
  - 标记实时同步中断
  - 安排 backoff 重连
  - 前后台切换时控制 stream 生命周期

### Pairing 引导

- `PairingFlowView` 文案改为 Cloudflare 新链路
- 完整安装消息同步为：
  - install-cloudflared
  - start-bridge
  - start-cloudflare-tunnel
  - show-connection
- 配对页错误也直接显示用户可理解的提示

## 结果

这一轮不增加底层能力，而是把已经存在的主链路做得更像可交付产品：

- 用户能看懂“为什么失败”
- 事件流中断后更容易自动恢复
- 安装引导与当前 skill 交付内容一致

## 后续建议

下一轮应继续补：

1. 服务端返回更稳定的 auth/session 诊断结构
2. runtime adapter 再向真实 supervisor 深接一层
3. restart 从“adapter 已处理”推进到“真实执行证据更强”
4. 命令白名单配置化与 runtime profile 适配
