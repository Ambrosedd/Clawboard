# Clawboard Skill-Hosted Bridge 架构设计

## 1. 为什么要从“独立 Connector”演进到“Skill-Hosted Bridge”

在早期草案里，Clawboard 使用了一个独立 Connector 的表述：

```text
iPhone App → Connector → Lobster Runtime
```

这在技术上成立，但产品上会带来两个问题：

1. 用户需要理解并部署一个额外组件，接入门槛偏高。
2. 如果龙虾本身已经支持安装 skill，单独强调 Connector 会显得重复。

因此，更适合当前产品方向的表达应该是：

> **Clawboard 作为一个安装在龙虾上的 skill 存在，由该 skill 拉起本地 bridge/sidecar 服务，负责与 App 连接，并承接原本 Connector 的职责。**

这样做的结果是：
- **产品层**：用户感知到的是“给龙虾安装一个官方 skill，然后扫码配对”。
- **工程层**：仍然保留清晰的连接层、控制层、授权层和安全边界。

---

## 2. 核心定义

### 2.1 Skill
Skill 是 Clawboard 能力的**安装入口**。

职责：
- 作为龙虾可安装扩展发布
- 提供启用/配置入口
- 拉起本地 bridge/sidecar
- 与龙虾 runtime 对接状态、任务、审批、事件

### 2.2 Sidecar / Bridge Service
Sidecar 是**贴着龙虾本体运行的本地辅助服务**。

可以把它理解为：
- 不是龙虾任务执行引擎本体
- 但和龙虾一起工作
- 负责连接、配对、控制、审批桥接、状态缓存、安全边界

职责：
- 生成配对码 / 二维码
- 与 iPhone App 建立安全连接
- 暴露结构化状态接口
- 接收 App 控制命令
- 发起审批请求并等待结果
- 执行有限白名单授权动作
- 缓存本地状态和事件

### 2.3 Lobster Runtime
龙虾本体仍然专注于：
- 执行任务
- 调用工具/skills
- 推进 workflow
- 汇报运行事件

不应该直接承担：
- 自我授权
- 任意提权
- 任意远程控制通道

---

## 3. 三层关系图

```text
┌──────────────────────────────┐
│         Clawboard App        │
│  - 查看状态                  │
│  - 审批请求                  │
│  - 发控制命令                │
└──────────────┬───────────────┘
               │ pair / token / secure channel
               ▼
┌──────────────────────────────┐
│  Clawboard Bridge Sidecar    │
│  - 配对与会话                │
│  - 状态缓存                  │
│  - 审批桥接                  │
│  - 控制命令入口              │
│  - 白名单授权执行            │
└──────────────┬───────────────┘
               │ runtime adapter / local IPC
               ▼
┌──────────────────────────────┐
│        Lobster Runtime       │
│  - 执行任务                  │
│  - 发起审批请求              │
│  - 输出状态与事件            │
└──────────────────────────────┘
```

如果加上安装入口，完整关系可以理解为：

```text
Lobster Skill System
   └─ 安装 Clawboard Skill
         ├─ 注册配置入口
         ├─ 拉起 Bridge Sidecar
         └─ 连接 Lobster Runtime 事件与控制
```

---

## 4. 用户视角的接入流程

### 4.1 理想用户流程
1. 用户在自己的龙虾环境中安装 `Clawboard skill`
2. skill 被启用后，自动拉起本地 bridge/sidecar
3. sidecar 生成配对码 / 二维码
4. 用户打开 iPhone App，点击“添加龙虾 / 扫码配对”
5. App 与 sidecar 完成 pair，换取长期 token
6. 用户立即在 App 中看到龙虾状态、任务、审批与告警

### 4.2 用户实际感知
用户感知到的是：
- 给龙虾安装了一个官方 skill
- 扫码配对
- 手机里看到状态

用户**不需要理解**：
- Connector
- Runtime Adapter
- Sidecar
- 本地控制面

这些都是内部实现概念。

---

## 5. 为什么推荐“Skill + Sidecar”而不是“所有逻辑都塞进 Skill 主逻辑”

### 方案 A：所有逻辑塞进 Skill 内部
#### 优点
- 概念上更简单
- 部署形态最少

#### 缺点
- 长连接、缓存、事件流、审批等待、重连恢复会越来越重
- 安全边界容易和任务执行逻辑混杂
- 后续维护和升级会变难

### 方案 B：Skill 作为入口，拉起独立 Sidecar
#### 优点
- 职责更清楚
- 连接与任务执行隔离更好
- 更适合长连接、状态缓存、审批桥接
- 安全边界更容易收口
- 出问题时可单独重启 bridge

#### 缺点
- 工程实现稍复杂

### 当前选择
选择 **方案 B**。

### 原因
Clawboard 的核心价值不只是“能看状态”，还包括：
- 长期连接 App
- 审批挂起和恢复
- 安全授权边界
- 未来的事件流与通知

这些能力更适合作为一个本地 bridge/sidecar 服务承载，而不是完全揉进 skill 主逻辑。

---

## 6. 数据流：状态查看

```text
Lobster Runtime
   ↓ 输出运行状态 / 任务事件 / 当前步骤
Bridge Sidecar
   ↓ 汇总、标准化、缓存
Clawboard App
   ↓ 拉取 / 订阅
显示首页、龙虾、任务、审批、告警
```

### 说明
Bridge Sidecar 的存在，使 App 不需要知道底层到底是：
- 长驻进程
- 脚本任务
- 现有 agent runtime
- 多 skill 协作

它只需要消费统一模型：
- lobsters
- tasks
- approvals
- alerts

---

## 7. 控制流：暂停 / 恢复 / 终止 / 重试

```text
App 发控制命令
   ↓
Bridge Sidecar 校验 token 与权限
   ↓
Bridge 调用 Runtime Adapter
   ↓
Lobster Runtime 执行控制动作
   ↓
Bridge 更新本地状态并回传 App
```

### 关键原则
- App 不是直接 SSH 到服务器执行命令
- Runtime 不暴露任意远控能力
- Bridge 只开放受控的结构化动作

---

## 8. 审批流：为什么龙虾不能自己给自己授权

这是整个系统最关键的安全原则之一：

> **龙虾可以发起授权请求，但不能自己批准，也不能自己扩大权限。**

### 审批流
```text
Lobster Runtime 运行到敏感步骤
   ↓
发起 approval request
   ↓
Bridge Sidecar 记录为 pending approval
   ↓
App 显示审批卡片
   ↓
用户批准 / 缩小范围批准 / 拒绝
   ↓
Bridge 执行本地白名单授权动作
   ↓
Runtime 获得临时 capability 或继续信号
```

---

## 9. 授权流：Bridge 如何执行授权

Bridge 不应该变成“任意提权器”。

正确做法应该是：
- 执行白名单动作
- 发放临时 capability
- scope 最小化
- TTL 明确
- 可审计

### 合理示例
- 允许 `crm_export(group_a, ttl=30m)`
- 允许 `s3_upload(release-bucket/tmp, ttl=15m)`
- 允许 `read_log(service_x, lines=200)`
- 代执行 `restart_service(service_x)` 这类固定动作

### 不合理示例
- 任意 shell
- 任意文件读写
- 任意数据库查询
- 给 runtime 长期 root 权限

---

## 10. 为什么这套架构在产品上更顺

### 对用户
用户理解的是：
- 龙虾支持安装官方 skill
- 安装后可以扫码接入手机
- 手机里可以看状态、处理审批、做控制

### 对工程
工程上仍然保留：
- 接入层
- 控制层
- 授权边界
- 状态聚合
- 演进空间

### 对安全
高风险能力仍然被收在本地：
- 不集中到云
- 不集中到手机
- 不交给普通任务执行逻辑自己做决定

---

## 11. 与“独立 Connector”表述的关系

可以把当前架构理解成：

> **Connector 的职责还在，但部署形态从“独立显式服务”演进成了“Skill-hosted Bridge / Sidecar”。**

也就是：
- 从产品上隐藏“Connector”概念
- 从工程上保留其职责边界

这不是推翻原设计，而是**更贴近龙虾生态的产品化表达**。

---

## 12. 当前推荐结论

### 当前推荐架构
```text
Clawboard App
   ↕
Clawboard Bridge Sidecar
   ↕
Lobster Runtime
```

而这套 bridge 能力通过：

```text
Clawboard Skill
   └─ 安装 / 启动 / 管理 Bridge Sidecar
```

来进入目标环境。

### 结论
Clawboard 不应长期依赖“让用户额外理解并部署 Connector”。

更合理的方向是：
- **把 Clawboard 做成龙虾 skill**
- **由 skill 拉起本地 bridge/sidecar**
- **由 bridge 承担连接、控制、审批、授权边界职责**
- **让用户只感知到“安装 skill → 扫码配对 → 在 App 查看和控制龙虾”**
