# Clawboard Bridge Skill Bundle

这是前期可交付版 skill bundle。

安装后你应该直接使用这些脚本，而不是手动翻内部目录：

- `scripts/start-bridge.sh` — 启动 Bridge
- `scripts/stop-bridge.sh` — 停止 Bridge
- `scripts/status-bridge.sh` — 查看运行状态
- `scripts/install-cloudflared.sh` — 下载 cloudflared 到 skill 自带运行目录
- `scripts/start-runtime-adapter.sh` — 启动 skill 自带 runtime state adapter
- `scripts/stop-runtime-adapter.sh` — 停止 runtime state adapter
- `scripts/status-runtime-adapter.sh` — 查看 runtime state adapter 状态
- `scripts/start-cloudflare-tunnel.sh` — 启动 Cloudflare Tunnel（HTTPS）
- `scripts/stop-cloudflare-tunnel.sh` — 停止 Cloudflare Tunnel
- `scripts/status-cloudflare-tunnel.sh` — 查看 Tunnel 状态
- `scripts/show-connection.sh` — 查看可发给手机的连接串（优先 HTTPS）
- `scripts/restart-lobster.sh` — 手动写入受限重启请求（会打印 request_id）

## 目录约定

- `config/bridge.env` — 本地配置
- `config/permission-profile.json` — 龙虾权限档位、runtime profile 与重启动作配置
- `runtime/connector/` — Bridge 运行时
- `runtime/runtime-state.json` — runtime adapter 输出的真实状态快照
- `runtime/auth-tokens.json` — 已签发 token 的持久化文件
- `runtime/capability-leases.json` — 当前生效中的临时授权租约
- `runtime/restart-requested.flag` — 受限重启请求标记（含 request_id / requested_by）
- `runtime/runtime-status.json` — runtime adapter 处理状态与重启执行证据摘要
- `logs/` — 运行日志
- `run/` — PID 等运行状态

## 推荐使用方式

安装完成后，推荐公网连接路径：

```bash
cd ~/.clawboard/skills/clawboard-bridge
bash scripts/start-runtime-adapter.sh
bash scripts/start-bridge.sh
bash scripts/install-cloudflared.sh
bash scripts/start-cloudflare-tunnel.sh
bash scripts/show-connection.sh
```

然后把输出的 HTTPS 连接串发给手机，在 Clawboard App 里“添加龙虾”。

如果只是同局域网内调试，也可以不启 tunnel，直接使用本地/局域网地址。

## Runtime profile 提示

当前 bridge 支持在 permission profile 中声明：

- `runtime_profile`
- `restart_action`

其中 `restart_action` 当前支持：
- `signal_file`：写入受限重启标记文件
- `supervisor_hint`：声明应由宿主 supervisor / container runtime 执行受控重启
- `none`：当前 profile 不支持 restart

注意：
- `supervisor_hint` 目前只作为能力声明与状态回传，不会让 bridge 直接获得任意宿主管理权限
- bridge 仍然遵守窄边界，不提供任意 shell / 任意远程管理能力
