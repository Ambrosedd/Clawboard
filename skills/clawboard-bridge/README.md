# Clawboard Bridge Skill Bundle

这是前期可交付版 skill bundle。

安装后你应该直接使用这些脚本，而不是手动翻内部目录：

- `scripts/start-bridge.sh` — 启动 Bridge
- `scripts/stop-bridge.sh` — 停止 Bridge
- `scripts/status-bridge.sh` — 查看运行状态
- `scripts/show-connection.sh` — 查看可发给手机的连接串
- `scripts/restart-lobster.sh` — 手动写入受限重启请求

## 目录约定

- `config/bridge.env` — 本地配置
- `config/permission-profile.json` — 龙虾权限档位与白名单配置
- `runtime/connector/` — Bridge 运行时
- `runtime/capability-leases.json` — 当前生效中的临时授权租约
- `runtime/restart-requested.flag` — 受限重启请求标记
- `logs/` — 运行日志
- `run/` — PID 等运行状态

## 推荐使用方式

安装完成后：

```bash
cd ~/.clawboard/skills/clawboard-bridge
bash scripts/start-bridge.sh
bash scripts/show-connection.sh
```

然后把输出的连接串发给手机，在 Clawboard App 里“添加龙虾”。
