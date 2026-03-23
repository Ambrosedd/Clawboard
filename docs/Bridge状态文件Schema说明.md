# Bridge 状态文件 Schema 说明

## 目标
定义 `STATE_FILE` 的稳定格式，让 runtime adapter / skill / sidecar 可以把真实运行态写给 Clawboard Bridge。

当前 schema 版本：
- `clawboard.bridge.state.v1`

配套文件：
- `connector/bridge-state.schema.json`
- `connector/sample-runtime-state.json`

---

## 顶层结构

```json
{
  "schema_version": "clawboard.bridge.state.v1",
  "generated_at": "2026-03-23T10:05:01Z",
  "lobsters": [],
  "tasks": [],
  "approvals": [],
  "alerts": []
}
```

要求：
- `schema_version` 必填
- `generated_at` 必填，表示该快照生成时间
- 四个列表字段都必填，允许为空数组

---

## 写入约定

推荐 adapter 按以下方式输出：

1. 先写临时文件
2. 完整写入 JSON
3. `rename` 原子替换目标文件

不要直接边写边覆盖目标文件，否则 Bridge 热重载时可能读到半截内容。

推荐模式：

```text
runtime-state.json.tmp -> rename -> runtime-state.json
```

---

## 最小字段约束

### lobsters
至少应包含：
- `id`
- `name`
- `status`
- `last_active_at`
- `risk_level`
- `node_id`
- `recent_logs`

### tasks
至少应包含：
- `id`
- `title`
- `status`
- `progress`
- `lobster_id`
- `current_step`
- `risk_level`
- `risk_score`
- `timeline`

### approvals
至少应包含：
- `id`
- `task_id`
- `lobster_id`
- `title`
- `reason`
- `scope`
- `expires_at`
- `risk_level`
- `status`

### alerts
至少应包含：
- `id`
- `level`
- `title`
- `summary`

---

## 当前建议的 adapter 输入形态

当前仓库内给了一个最小示例：
- `connector/runtime-events.sample.jsonl`
- `connector/tools/runtime-jsonl-to-state.js`

作用：
- 读取 JSONL 事件流
- 聚合为 bridge state JSON
- 原子写出到目标文件

这只是一个参考 adapter，不是唯一标准。

真正的 runtime 可以：
- 直接写快照
- 或先输出事件流，再聚合成快照

---

## 兼容性原则

Bridge 应优先维持 App-facing API 稳定，
而不是要求 App 跟随不同 runtime 的内部数据结构变化。

也就是说：
- runtime 可以变化
- adapter 可以变化
- `STATE_FILE` schema 尽量稳定
- App 不应该直接知道底层 runtime 细节

---

## ## 校验与错误处理

当前 Bridge 在读取 `STATE_FILE` 时会做基础 schema 校验：
- 校验通过：加载新状态，发 `runtime.state.reloaded`
- 校验失败：保留上一份有效状态，发 `runtime.state.invalid`
- `/health` 中可看到 `state_status`

这意味着 adapter 接错格式时，不会默默把 Bridge 状态污染掉。

---

## 当前结论

`STATE_FILE` 的意义不是权宜之计，而是一个重要边界：

> runtime 负责采集，bridge 负责对外暴露稳定控制面。

这会让 Clawboard 更容易适配不同的 lobster/runtime 实现。
