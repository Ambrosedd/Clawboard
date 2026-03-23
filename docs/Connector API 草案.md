# Clawboard Connector API 草案

## 1. 设计目标
Connector API 的目标是为 iPhone App 提供一个 **轻量、安全、稳定** 的本地控制接口。

原则：
- 默认只暴露必要能力
- 不开放任意 shell 与任意文件访问
- 兼容未来扩展到 Relay / Cloud 模式
- 接口尽量稳定，方便 App 与 Connector 并行演进

---

## 2. 鉴权

### 2.1 配对流程
1. Connector 首次启动生成一次性配对码 / 二维码
2. App 扫码后提交配对请求
3. Connector 返回长期 token
4. App 将 token 存储在 iOS Keychain

### 2.2 Header
```http
Authorization: Bearer <token>
```

---

## 3. 基础接口

### GET /health
返回 Connector 健康状态。

响应示例：
```json
{
  "status": "ok",
  "version": "0.1.0",
  "time": "2026-03-22T00:00:00Z"
}
```

### GET /device/info
返回节点设备信息。

```json
{
  "id": "node-1",
  "name": "MacBook-Pro",
  "platform": "macOS",
  "connector_version": "0.1.0",
  "network_mode": "direct"
}
```

---

## 4. 龙虾接口

### GET /lobsters
获取龙虾列表。

```json
{
  "items": [
    {
      "id": "lobster-1",
      "name": "分析龙虾 A-01",
      "status": "busy",
      "task_title": "客户报告生成",
      "last_active_at": "2026-03-22T00:00:00Z",
      "risk_level": "medium",
      "node_id": "node-1"
    }
  ]
}
```

### GET /lobsters/:id
获取单个龙虾详情。

```json
{
  "id": "lobster-1",
  "name": "分析龙虾 A-01",
  "status": "busy",
  "current_task": {
    "id": "task-1",
    "title": "客户报告生成",
    "progress": 72,
    "current_step": "crm_export"
  },
  "recent_logs": [
    "step plan completed",
    "step search completed",
    "waiting approval for crm_export"
  ]
}
```

---

## 5. 任务接口

### GET /tasks
获取任务列表。

可选 query：
- `status`
- `lobster_id`
- `risk_level`

### GET /tasks/:id
获取任务详情。

```json
{
  "id": "task-1",
  "title": "客户报告生成",
  "status": "waiting_approval",
  "progress": 72,
  "lobster_id": "lobster-1",
  "timeline": [
    { "step": "plan", "status": "done" },
    { "step": "search", "status": "done" },
    { "step": "crm_export", "status": "waiting_approval" }
  ],
  "input_summary": "生成客户组 A 周报",
  "output_summary": null,
  "error_reason": null
}
```

---

## 6. 审批接口

### GET /approvals
获取待审批列表。

```json
{
  "items": [
    {
      "id": "approval-1",
      "task_id": "task-1",
      "lobster_id": "lobster-1",
      "title": "请求 CRM 导出权限",
      "reason": "生成完整客户报告",
      "scope": "客户组 A",
      "expires_at": "2026-03-22T00:30:00Z",
      "risk_level": "high"
    }
  ]
}
```

### POST /approvals/:id/approve
批准审批项。

请求体：
```json
{
  "granted_scope": "customer_group_a",
  "duration_minutes": 30
}
```

### POST /approvals/:id/reject
拒绝审批项。

请求体：
```json
{
  "reason": "当前不允许导出该数据范围"
}
```

---

## 7. 告警接口

### GET /alerts
获取当前告警。

```json
{
  "items": [
    {
      "id": "alert-1",
      "level": "P2",
      "title": "任务异常重试过多",
      "summary": "任务 task-1 在 10 分钟内失败 3 次",
      "related_type": "task",
      "related_id": "task-1"
    }
  ]
}
```

---

## 8. 控制接口

### POST /lobsters/:id/pause
暂停龙虾执行。

### POST /lobsters/:id/resume
恢复龙虾执行。

### POST /lobsters/:id/terminate
终止龙虾当前任务。

### POST /tasks/:id/retry
重试任务。

统一响应建议：
```json
{
  "ok": true,
  "action": "pause",
  "target_id": "lobster-1"
}
```

---

## 9. 实时事件流

### GET /stream/events
支持 SSE 或 WebSocket。

事件示例：
```json
{
  "event": "task.waiting_approval",
  "time": "2026-03-22T00:10:00Z",
  "data": {
    "task_id": "task-1",
    "approval_id": "approval-1"
  }
}
```

建议事件类型：
- `bridge.started`
- `pair.exchanged`
- `auth.revoked`
- `runtime.state.reloaded`
- `runtime.state.invalid`
- `lobster.status.changed`
- `task.progress.updated`
- `task.waiting_approval`
- `task.failed`
- `approval.created`
- `approval.resolved`
- `alert.created`
- `alert.resolved`

当前骨架版已先实现：
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

---

## 10. 错误模型
统一错误响应建议：

```json
{
  "error": {
    "code": "approval_expired",
    "message": "approval request already expired"
  }
}
```

建议错误码：
- `unauthorized`
- `forbidden`
- `not_found`
- `invalid_request`
- `approval_expired`
- `runtime_unavailable`
- `connector_busy`

---

## 11. 当前安全边界
Connector 当前默认仅允许：
- 状态查看
- 任务查看
- 审批处理
- 暂停 / 恢复 / 终止 / 重试

明确不默认开放：
- 任意 shell 执行
- 任意文件读写
- 任意数据库查询
- 任意外部网络代理能力

这保证 App 只是“移动观察与控制界面”，而不是远程高危运维入口。
