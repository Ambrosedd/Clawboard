# 决策日志-第15轮 Skill 可交付化

## 背景
用户指出了当前最关键的问题：

> 虽然 App 配对路径和 Bridge API 在持续推进，但用户实际上拿不到“配对 skill”。

这说明当前主要矛盾已经不是“连接页如何再简化一点”，而是：

> `clawboard-bridge` 还停留在说明型 skill，而不是可安装、可启动、可交付的 skill bundle。

---

## 这轮目标
把 `clawboard-bridge` 从：
- 设计文档 + SKILL.md

推进到：
- 安装后就有运行时、配置、启停脚本、连接串查看脚本的前期可交付 bundle

---

## 本轮做法

### 1. skill 目录补齐可执行内容
新增：
- `README.md`
- `skill.env.example`
- `scripts/start-bridge.sh`
- `scripts/stop-bridge.sh`
- `scripts/status-bridge.sh`
- `scripts/show-connection.sh`

### 2. 安装脚本升级
安装脚本不再只是复制说明型 skill，而是同时：
- 复制 skill bundle
- 复制 `connector/` runtime 到 `runtime/connector/`
- 生成 `config/bridge.env`
- 初始化 `logs/`、`run/`
- 给出启动命令和连接串查看命令

### 3. 用户路径收敛
安装后用户不必再理解内部结构，只需要：

```bash
cd ~/.clawboard/skills/clawboard-bridge
bash scripts/start-bridge.sh
bash scripts/show-connection.sh
```

然后把连接串发给手机即可。

---

## 为什么先做这个，而不是继续二维码
因为二维码属于“连接体验优化”，而 skill 可交付化属于“产品是否真正可拿到”的前置条件。

如果用户连 skill 都拿不到，二维码做得再漂亮也没有意义。

---

## 当前结论
这轮的意义不是新增 API，而是补上产品交付链的第一步：

> 让用户第一次真的能拿到、装上、启动 `clawboard-bridge`。
