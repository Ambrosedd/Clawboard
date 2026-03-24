# 决策日志 - 第32轮：supervisor_hint 增加受控回执文件

## 背景

到第 31 轮为止：

- `legacy` profile 已经能通过 `signal_file` 形成 restart 请求链
- `container` / `supervised` profile 已经能通过 `supervisor_hint` 声明“应由宿主执行”

但问题是：

- `supervisor_hint` 还只是声明
- App 和 diagnostics 看到的仍主要是“bridge 说它请求了”
- 缺少一个不扩权前提下的、本地 supervisor/container runtime 可消费的结果落点

## 本轮目标

在不把 bridge 变成宿主管理器的前提下，把：

- `container`
- `supervised`

从“只有 hint”推进到“有可控回执文件可回填结果”。

## 本轮实现

### 1. `supervisor_hint` 支持 `ack_file`

permission profile 中的 restart action 现在可配置：

```json
{
  "type": "supervisor_hint",
  "target": "host_supervisor",
  "ack_file": "./runtime/restart-ack.supervised.json"
}
```

### 2. bridge 发起 restart 时写入受控 ack/request 文件

当 `restart_action.type === "supervisor_hint"` 且存在 `ack_file` 时，bridge 会写入 JSON：

- `status: requested`
- `request_id`
- `requested_at`
- `requested_by`
- `runtime_profile`
- `target`
- `lobster_id`
- `task_id`
- `result`
- `evidence`

这样本地 supervisor/container runtime 可以：

1. 读取该文件
2. 执行受控 restart
3. 回填 `status/result/evidence`

### 3. API 摘要中暴露 `ack_file`

`summarizeRestartAction()` 现在会把：

- `type`
- `target`
- `ack_file`

一起暴露给 App / diagnostics。

## 为什么这么做

这是一个刻意保守的设计：

- bridge **不直接执行** `systemctl` / `docker restart` / 任意命令
- bridge 只负责：
  - 表达 profile 能力
  - 产生 restart request
  - 给本地受控执行器一个稳定回执文件落点

也就是说，执行权仍在本地 supervisor/container runtime 手里。

## 结果

这一轮之后：

- `legacy`：继续 signal file 路径
- `container` / `supervised`：从纯 hint 升级到“hint + 受控 ack 文件落点”

这还不是最终真实执行器集成，但比单纯声明前进了一步：

**bridge 已经能为宿主执行器提供稳定的 request/result 文件契约，而不是只说‘请外面自己想办法’。**

## 后续可继续做

1. 让 runtime adapter / connector 读取 `ack_file` 的结果并合并进 `runtime_status`
2. 统一 `requested / acknowledged / completed / failed` 的状态枚举
3. 为 container / supervised 提供本地示例 sidecar / wrapper，而不是只给配置示例
