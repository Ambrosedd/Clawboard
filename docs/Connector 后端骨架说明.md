# Connector 后端骨架说明

本轮新增了一个可本地运行的 `connector/` 目录，目标是把文档中的 Connector API 草案落成一个**最小可运行实现**。

## 本轮实现内容

- 新建 `connector/` 目录
- 用 Node.js 原生 `http` 提供本地服务
- 提供文档对齐的基础接口：
  - `/health`
  - `/device/info`
  - `/lobsters`
  - `/lobsters/:id`
  - `/tasks`
  - `/tasks/:id`
  - `/approvals`
  - `/alerts`
- 提供基础控制动作：
  - `/lobsters/:id/pause`
  - `/lobsters/:id/resume`
  - `/lobsters/:id/terminate`
  - `/tasks/:id/retry`
  - `/approvals/:id/approve`
  - `/approvals/:id/reject`
- 用内存种子数据模拟一个初始节点、龙虾、任务、审批与告警

## 为什么是这个形态

当前项目文档已经反复强调：

- App First
- 本地优先
- 默认安全克制
- 不过早引入重型架构

因此 Connector 第一版故意不做这些事：

- 不引入重 Web 框架
- 不接数据库
- 不暴露任意 shell / 文件系统
- 不做复杂多租户逻辑

## 当前限制

- 数据仅存在内存中，重启会重置
- 还没有真实 runtime adapter
- 还没有事件流 `/stream/events`
- 鉴权只保留了 `API_TOKEN` 这种最小形态

## 为什么仍然值得

因为这已经足够支撑：

1. iOS 端开始从 Mock 切到真实 HTTP 请求
2. 页面模型验证是否与接口草案一致
3. 后续接真实 runtime 时，只替换数据来源，不需要推翻 API 表面

## 建议的下一阶段

### Phase 2.1
- 增加 SSE 事件流
- 增加统一错误码测试
- 增加简单持久化（JSON 文件即可）

### Phase 2.2
- 接入真实 runtime 状态源
- 支持审批状态事件回流
- 补配对 / token 发放流程
