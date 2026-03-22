# Clawboard Connector

一个**本地优先、零运行时依赖、可直接跑起来**的 Connector 后端骨架。

当前目标不是做完整 runtime，而是给 iOS App 和后续适配层一个稳定的本地 API 起点。

## 为什么这样做

这版选择了最轻的实现路线：

- 使用 Node.js 原生 `http`
- 不引入 Express / Fastify / 数据库
- 使用内存中的种子数据模拟 runtime 状态
- 接口尽量贴近 `docs/Connector API 草案.md`

这样做的好处：

- 启动成本低
- 方便在本机、VPS、开发机快速验证
- API 结构先稳定下来，后续再替换底层实现
- 不会因为过早工程化拖慢产品闭环

代价也很明确：

- 当前状态**不会持久化**，服务重启后会重置
- 暂未接入真实 Lobster Runtime
- 暂未实现 SSE / WebSocket 事件流
- 鉴权只保留了最小骨架，默认可本地无 token 启动

## 已实现接口

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

## 环境变量

- `HOST`：监听地址，默认 `0.0.0.0`
- `PORT`：监听端口，默认 `8787`
- `CONNECTOR_NAME`：设备名称
- `NODE_ID`：节点 ID
- `PLATFORM`：平台名
- `NETWORK_MODE`：连接模式，默认 `direct`
- `API_TOKEN`：如果设置，则要求请求头 `Authorization: Bearer <token>`

## 示例

```bash
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/lobsters
curl http://127.0.0.1:8787/tasks?status=waiting_approval
curl -X POST http://127.0.0.1:8787/approvals/approval-1/approve \
  -H 'Content-Type: application/json' \
  -d '{"granted_scope":"customer_group_a","duration_minutes":30}'
```

如果配置了 `API_TOKEN`：

```bash
curl http://127.0.0.1:8787/device/info \
  -H 'Authorization: Bearer your-token'
```

## 当前设计取舍

### 1. 先不引入 Web 框架
原因：当前只是 Connector MVP 骨架，Node 原生 `http` 足够覆盖现有接口，依赖更少。

### 2. 先不做持久化
原因：这一轮重点是**接口稳定**和**App 对接**，不是状态恢复。

### 3. 先不做事件流
原因：文档里已经预留了 `/stream/events`，但第一轮先把拉取 + 控制闭环跑通更划算。

### 4. 鉴权保留最小骨架
原因：文档要求未来走配对 / token，但本地开发阶段需要低摩擦启动；因此通过 `API_TOKEN` 开关兼顾两者。

## 下一步建议

1. 增加 `GET /stream/events`（先做 SSE）
2. 抽出 `RuntimeAdapter` 接真实 agent runtime
3. 增加 `StateCache` 与简单本地持久化
4. 接入配对码 / token 换取流程
5. 补统一错误码与接口测试
