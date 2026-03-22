# Clawboard Bridge Skeleton

一个**本地优先、零运行时依赖、可直接跑起来**的 Clawboard Bridge / Sidecar 骨架。

当前目标不是做完整 runtime，而是给 iOS App、龙虾 skill，以及后续真实 bridge 适配层一个稳定的本地 API 起点。

## 这是什么

当前推荐架构已经从“独立 Connector”进一步收敛为：

- **Clawboard 作为龙虾 skill 安装**
- **skill 拉起本地 bridge / sidecar**
- **bridge 承担配对、状态暴露、控制、审批桥接、安全边界职责**

因此，这个 `connector/` 目录现在更适合理解为：

> **Clawboard Bridge Skeleton**

它保留了早期 connector 的职责，但语义上更接近未来真正的 skill-hosted bridge。

## 为什么这样做

这版仍然选择最轻的实现路线：

- 使用 Node.js 原生 `http`
- 不引入 Express / Fastify / 数据库
- 使用内存中的种子数据模拟 runtime 状态
- 补上第一版 pair 配对协议骨架
- 接口尽量贴近 `docs/Connector API 草案.md` 与 `docs/Pair 配对协议设计.md`

这样做的好处：

- 启动成本低
- 方便在本机、VPS、开发机快速验证
- 先把 App ↔ Bridge 的配对与 API 形状定住
- 后续便于迁移到真正的 skill-hosted sidecar

## 已实现接口

### 配对
- `GET /pair/session`
- `POST /pair/exchange`

### 基础
- `GET /health`
- `GET /device/info`

### 龙虾
- `GET /lobsters`
- `GET /lobsters/:id`
- `POST /lobsters/:id/pause`
- `POST /lobsters/:id/resume`
- `POST /lobsters/:id/terminate`

### 任务
- `GET /tasks`
- `GET /tasks/:id`
- `POST /tasks/:id/retry`

### 审批
- `GET /approvals`
- `POST /approvals/:id/approve`
- `POST /approvals/:id/reject`

### 告警
- `GET /alerts`

## 运行

要求：Node.js 20+

```bash
cd connector
cp .env.example .env   # 可选，仅作参考
npm start
```

默认监听：`http://0.0.0.0:8787`

启动后会打印：
- bridge 监听地址
- 一次性 pair code
- pair code 过期时间

## 环境变量

- `HOST`：监听地址，默认 `0.0.0.0`
- `PORT`：监听端口，默认 `8787`
- `CONNECTOR_NAME`：设备名称
- `NODE_ID`：节点 ID
- `PLATFORM`：平台名
- `NETWORK_MODE`：连接模式，默认 `direct`
- `API_TOKEN`：预置长期 token（可选）
- `PAIR_CODE`：启动时指定配对码（可选）

## 配对示例

### 1. 读取当前 pair session
```bash
curl http://127.0.0.1:8787/pair/session
```

### 2. 用配对码换 token
```bash
curl -X POST http://127.0.0.1:8787/pair/exchange \
  -H 'Content-Type: application/json' \
  -d '{
    "pair_code":"LX-472911",
    "device_name":"iPhone 16 Pro",
    "client_name":"Clawboard iOS",
    "client_version":"0.1.0"
  }'
```

### 3. 用返回 token 请求状态
```bash
curl http://127.0.0.1:8787/device/info \
  -H 'Authorization: Bearer cb_live_xxx'
```

## 当前设计取舍

### 1. 先补 pair 协议骨架
原因：下一阶段 App 与真实 bridge 的连接，首先要有稳定的首次信任建立流程。

### 2. 仍然先不做持久化
原因：这一轮重点是**pair 协议 + bridge API 形状**，不是状态恢复。

### 3. 仍然先不做事件流
原因：先把“配对 → 获取 token → 拉取状态 → 发控制命令”跑通更划算。

### 4. 仍然不开放任意执行能力
原因：bridge 的目标是安全边界，而不是远控入口。

## 下一步建议

1. iOS 配对页接入 `/pair/session` / `/pair/exchange`
2. 将 token 存入 Keychain
3. bridge 增加 token 撤销与 pair session 刷新
4. 抽出 Runtime Adapter 接真实龙虾 skill/runtime
5. 再补 SSE / WebSocket 事件流
