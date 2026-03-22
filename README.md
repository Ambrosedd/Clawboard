# Clawboard

龙虾 OS / Clawboard 项目仓库。

当前已提交的主要内容：
- `docs/需求文档.md`
- `docs/设计文档.md`
- `docs/Connector API 草案.md`
- `docs/实施计划与决策日志.md`
- `docs/决策日志-第1轮实现反思.md`
- `docs/决策日志-第2轮实现反思.md`
- `ios/` SwiftUI Demo 工程
- `prototype/` 可点击交互原型
- `connector/` 本地优先 Connector / Bridge 后端骨架
- `skills/` Clawboard skill 设计骨架
- `install/` 前期安装与连接脚本

## 当前最重要的路径

### 连接服务器上的龙虾
当前优先目标是先把“连接这一步”做顺。

请先看：
- `docs/服务器龙虾连接说明.md`
- `install/README.md`

当前推荐流程：
1. 在服务器侧安装并启用 `clawboard-bridge` skill
2. 启动本地 Bridge
3. 在 iPhone App 中进入“设置” → “添加龙虾”
4. 输入配对码（必要时再展开高级选项填写地址）

## 当前可运行部分

### 1. 交互原型
见 `prototype/README.md`

### 2. Connector / Bridge 本地服务骨架
见 `connector/README.md`

可直接运行：

```bash
cd connector
npm start
```

默认提供以下接口：
- `GET /health`
- `GET /device/info`
- `GET /lobsters`
- `GET /tasks`
- `GET /approvals`
- `GET /alerts`
- `GET /pair/session`
- `POST /pair/exchange`
- 以及对应的基础详情与控制接口

### 3. iOS Demo 当前能力
- 已具备首页 / 龙虾 / 任务 / 审批 / 设置 5 个主 Tab
- 已补充 loading / empty / error 三类状态
- 已建立审批、任务、龙虾、告警之间的联动
- 可在设置页切换标准 / 空状态 / 错误恢复三种演示场景
- 已增加“添加龙虾”入口与真实 pair 协议骨架
- 仍保持无额外重依赖的轻量 SwiftUI 方案

## 下一步可以继续推进
- 扫码连接与二维码展示
- Keychain 存储与 token 生命周期管理
- iOS 端从 Demo 场景与 MockData 切换到真实 Bridge HTTP
- 增加 `/stream/events` 事件流
- 对接真实 Lobster Runtime Adapter
- 补强异常诊断、重试与更完整的闭环行为
