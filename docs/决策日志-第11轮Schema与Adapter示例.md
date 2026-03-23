# 决策日志-第11轮 Schema 与 Adapter 示例

## 本轮目标
把“Bridge 支持外部状态文件”继续推进到：
- 有明确 schema
- 有可照抄的 adapter 示例
- 有实际可跑的生成链路

---

## 1. 为什么这轮优先做 schema，而不是继续扩 App

在上一轮之后，Bridge 已经能读取 `STATE_FILE`。
但如果没有稳定 schema，实际问题会马上出现：
- 不同 adapter 各写各的字段
- App-facing 模型被 runtime 内部细节污染
- 每接一个新环境都得重新猜格式

所以当前更值钱的不是再加一个新 UI，而是把：

> **Bridge 与 runtime adapter 之间的契约固定下来。**

这一步做稳，后面的 skill、sidecar、脚本接入才不会一直返工。

---

## 2. 本轮选择的做法

### A. 文档说明 schema
优点：
- 简单

缺点：
- 容易理解不一致
- 很难机器校验

### B. 只给 sample JSON
优点：
- 直观

缺点：
- 只能“看着像”，没有边界
- 字段缺漏和类型问题不容易发现

### C. 文档 + JSON Schema + adapter 示例
优点：
- 人能看
- 机器能校验
- 接入方能直接照着跑

缺点：
- 工作量略高

### 当前选择
选择 **C：文档 + schema + adapter 示例**。

这是第一次真正把“外部状态接入”从概念推进到工程接口层。

---

## 3. 本轮实际产物

新增：
- `connector/bridge-state.schema.json`
- `docs/Bridge状态文件Schema说明.md`
- `connector/runtime-events.sample.jsonl`
- `connector/tools/runtime-jsonl-to-state.js`
- `connector/package.json` 中的 `build:sample-state` script

能力：
1. 定义 `clawboard.bridge.state.v1`
2. 提供标准快照格式
3. 提供 JSONL 事件流 → bridge state 的最小聚合示例
4. 使用原子写入输出目标状态文件

---

## 4. 为什么 adapter 示例选 JSONL 聚合

这是一个刻意保守但高兼容的选择。

原因：
- 很多 runtime/脚本天然就适合吐 event log
- JSONL 很容易拼接、流式写、调试
- adapter 可以独立演进，不绑死某种私有协议

这让当前最小可行链路变成：

```text
runtime events (jsonl)
   ↓
adapter 聚合
   ↓
bridge state json
   ↓
Clawboard Bridge
   ↓
App
```

这条链很适合现在的阶段：
- 可本地验证
- 可逐步替换上游 runtime
- 不要求 Bridge 直接理解所有 runtime 私有细节

---

## 5. 验证结果

已实际验证：
1. 使用 `runtime-events.sample.jsonl`
2. 运行 `tools/runtime-jsonl-to-state.js`
3. 生成 `sample-runtime-state.generated.json`
4. Bridge 通过 `STATE_FILE` 读取该文件启动
5. App-facing `/tasks` 正常返回聚合结果

说明当前不是“只有格式”，而是已经形成了可工作的样板链路。

---

## 6. 当前仍然故意没做的部分

这轮没做：
- schema 严格校验器集成到 bridge 启动流程
- 多 node 聚合冲突处理
- 控制命令回写 adapter / runtime
- approval 结果回灌到事件流上游
- adapter 守护进程化

因为现在更重要的是：
先把接入格式和样板链路固定，而不是一次把整个 runtime bridge 系统做满。

---

## 7. 当前结论

这一轮之后，Clawboard 已经具备：
- App
- Bridge
- SSE
- 外部状态文件
- 状态 schema
- adapter 示例

这意味着“接现有环境”第一次有了比较清晰、可复制的工程入口。

下一步最值钱的方向会是：
1. 做一个更贴近实际运行环境的 adapter（例如读某个本地状态目录 / 任务日志）
2. 设计控制动作如何安全回写给 adapter / runtime
3. 给 bridge 增加 state schema 校验与错误事件输出
