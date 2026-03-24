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

- 默认种子状态**不会持久化**，服务重启后会重置
- 暂未直接嵌入真实 Lobster Runtime
- 多设备会话管理仍较轻量

但当前版本已经新增一个更接近真实接入的中间态：
- 可通过 `STATE_FILE=/path/to/runtime-state.json` 注入外部运行时快照
- Bridge 会热重载该 JSON 文件，并继续对 App 暴露稳定 API 与 SSE 事件

## 已实现接口

### 配对与凭证
- `GET /pair/session`
- `POST /pair/exchange`
- `GET /auth/session`
- `POST /auth/revoke`
- `GET /debug/diagnostics`（本地请求免鉴权，用于排障）

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
- `runtime.state.reloaded`
- `runtime.state.invalid`
- `lobster.status.changed`
- `task.progress.updated`
- `task.failed`
- `approval.resolved`
- `alert.created`

## 外部运行时状态注入

如果你已经有一个本地进程、skill、或脚本能把当前 lobster 运行态写成 JSON，
可以让 Bridge 直接读取它：

```bash
cd connector
STATE_FILE=./sample-runtime-state.json node src/server.js
```

特点：
- Bridge 启动时读取该文件
- 文件变化时自动热重载
- 对外 API 结构保持不变
- 有效状态会发出 `runtime.state.reloaded` 事件
- 非法状态会保留上一份有效状态，并发出 `runtime.state.invalid` 事件
- `/health` 会显示当前 state 校验状态

这样可以把“真实运行态采集”与“对 App 暴露稳定 API / 鉴权 / 配对 / SSE”解耦。

## 诊断能力

当前 bridge 已补充一层更明确的诊断返回：

- `401 unauthorized` 会附带 `diagnostics`
  - `auth_state`: `missing` / `invalid` / `revoked` / `active`
  - `pair_session.state`: `active` / `expired`
  - `bridge.runtime_status`
- `GET /auth/session` 会返回当前 token 的创建时间、撤销时间、认证状态
- `GET /device/info` / `GET /capabilities/leases` 会附带 runtime 状态
- `GET /debug/diagnostics` 可用于本地排障，查看 token 列表摘要、runtime 状态、lease 状态

这能帮助 App 区分：
- token 失效
- 配对会话过期
- bridge 本身不可达
- runtime 处于何种状态

### Schema 与 adapter 示例

仓库中已附带：
- `bridge-state.schema.json`：状态文件 schema
- `sample-runtime-state.json`：快照示例
- `runtime-events.sample.jsonl`：事件流示例
- `tools/runtime-jsonl-to-state.js`：把 JSONL 聚合成状态快照的最小 adapter

示例：

```bash
cd connector
npm run build:sample-state
STATE_FILE=./sample-runtime-state.generated.json node src/server.js
```

这条链适合当前阶段验证：
- runtime / skill 输出事件
- adapter 聚合为标准快照
- bridge 校验 schema、保留最后有效状态
- bridge 负责对 App 暴露统一 API

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
