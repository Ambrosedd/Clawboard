# Clawboard Bridge

一个**本地优先、零运行时依赖、可直接跑起来**的 Bridge / sidecar 骨架。

当前目标不是做完整 runtime，而是给 iOS App 和后续 Lobster skill 适配层一个稳定的本地 API 起点。

## 为什么这样做

这版选择了最轻的实现路线：

- 使用 Node.js 原生 `http`
- 不引入 Express / Fastify / 数据库
- 使用内存中的种子数据模拟 runtime 状态
- 接口尽量贴近 `docs/Connector API 草案.md` 与当前 Pair / Auth 设计

这样做的好处：

- 启动成本低
- 方便在本机、VPS、开发机快速验证
- API 结构先稳定下来，后续再替换底层实现
- 不会因为过早工程化拖慢产品闭环

代价也很明确：

- 当前状态**不会持久化**，服务重启后会重置
- 暂未接入真实 Lobster Runtime
- 暂未实现 SSE / WebSocket 事件流
- 鉴权目前仍是本地内存态 token 管理

## 已实现接口

### 配对与凭证
- `GET /pair/session`
- `POST /pair/exchange`
- `GET /auth/session`
- `POST /auth/revoke`

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

### 实时事件流
- `GET /stream/events`（SSE）

当前会推送的代表性事件包括：
- `bridge.started`
- `pair.exchanged`
- `auth.revoked`
- `lobster.status.changed`
- `task.progress.updated`
- `task.failed`
- `approval.resolved`
- `alert.created`

## 运行

```bash
cd connector
node src/server.js
```

默认监听：
- `http://0.0.0.0:8787`

## 环境变量
参考：
- `.env.example`

关键项：
- `HOST`
- `PORT`
- `CONNECTOR_NAME`
- `NODE_ID`
- `PLATFORM`
- `NETWORK_MODE`
- `PAIR_CODE`
- `API_TOKEN`

## 当前定位

它现在更适合被理解为：

> **由 Clawboard skill 拉起的本地 Bridge 运行时骨架**

而不是一个要被用户单独理解和部署的产品。

## 下一步

- 把 token 存储从内存态升级为可控持久化 / 撤销模型
- 接入真实 Lobster runtime adapter
- 增加事件流（SSE / WebSocket）
- 增加多设备 token 管理与会话枚举
- 接入 skill 生命周期管理
