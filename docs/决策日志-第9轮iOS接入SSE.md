# 决策日志-第9轮 iOS 接入 SSE

## 本轮目标
让 iOS 在真实 Bridge 模式下，从“主要靠手动刷新 / 操作后刷新”继续推进到“具备近实时同步体验”。

---

## 1. 为什么这轮不直接做本地增量状态合并

在服务端 SSE 已经建立后，iOS 端有两种接法：

### 方案 A：事件到达后直接在本地增量修改状态
**优点**
- 更实时
- UI 更丝滑
- 网络请求更少

**缺点**
- 事件语义和本地模型要强绑定
- 需要处理乱序、补偿、断线重连、局部状态不一致
- 当前阶段服务端事件模型还在继续演进，太早做细粒度本地 reducer，返工概率高

### 方案 B：先把 SSE 当作“实时触发器”
即：
- 长连收到关键事件
- 本地 debounce 一下
- 自动 refresh 全量快照

**优点**
- 风险低
- 接入快
- 用户体验已经从“手动刷新”升级到“近实时自动同步”
- 保持 App 模型和 Bridge 模型对齐，不容易漂

**缺点**
- 还不是最丝滑
- 事件很多时仍有重复拉取成本

### 当前选择
选择 **方案 B**。

原因很实际：
> 先把“自动跟上真实状态变化”做稳，再把“增量更新更优雅”做细。

---

## 2. 本轮实现内容

iOS 新增：
- `BridgeEventStreamClient.swift`

能力包括：
- 建立带 Bearer token 的 `/stream/events` SSE 长连
- 解析 `id:` / `event:` / `data:`
- 保留 `Last-Event-ID` 用于后续重连补发

`AppViewModel` 新增：
- `isRealtimeSyncActive`
- `eventStreamTask`
- `pendingRefreshTask`
- `lastBridgeEventID`

行为变化：
1. 恢复已有 Bridge 连接时自动尝试接 SSE
2. 新完成配对时自动接 SSE
3. 断开连接 / reset demo 时停止 SSE
4. 收到关键事件后，做一次短 debounce 再自动 refresh
5. UI 增加实时同步状态提示

当前已监听触发刷新的事件：
- `bridge.started`
- `pair.exchanged`
- `auth.revoked`
- `lobster.status.changed`
- `task.progress.updated`
- `task.failed`
- `approval.resolved`
- `alert.created`

---

## 3. 为什么这是正确的中间态

这一轮的重点不是“把 SSE 接上”本身，而是：

> **让真实 Bridge 模式开始具备持续同步能力，而不是一个操作完成才顺手刷一次的静态客户端。**

这对产品感知很重要：
- 用户会开始感觉系统“活着”
- 任务推进、审批变化、暂停恢复不再明显依赖人工刷新
- 也为后续通知和更细的状态联动打基础

---

## 4. 仍然保留的限制

### A. 还不是本地增量同步
当前仍是：
- SSE 收到事件
- 自动刷新快照

不是：
- 直接把事件映射成局部 UI 更新

### B. 断线重连策略还比较轻
虽然已经保留 `Last-Event-ID`，但还没做：
- 更强的退避重连
- 后台/前台切换场景的精细恢复
- 连接失败后的重试状态机

### C. 事件语义还可以继续丰富
后续更适合继续补：
- `approval.created`
- `alert.resolved`
- 更细粒度的 task step 事件
- runtime adapter 输出的标准化事件

---

## 5. 当前结论

本轮完成后，Clawboard iOS 已经从：
- 真实 Bridge + 手动刷新为主

推进到：
- **真实 Bridge + SSE 驱动的近实时自动同步**

这是一种很合理的工程节奏：
- 不过早把本地状态管理做复杂
- 但已经明显提升真实可用体验

下一阶段如果继续优化，优先顺序应该是：
1. SSE 断线重连与退避
2. 关键事件的本地增量应用
3. runtime adapter 更真实的数据源
