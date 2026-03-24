# 决策日志 - 第34轮：补齐 mock supervisor ack 闭环

## 背景

第 33 轮之后：

- bridge 已能写 `ack_file`
- connector 已能读取 `ack_file`
- iOS / diagnostics 已能展示 ack 状态

但仍有一个现实问题：

- 没有本地示例执行器的话，这条链很难验证
- 每次都要靠想象“未来 supervisor 会怎么回填”并不利于回归测试

## 本轮目标

补一组本地演示脚本，让：

- `requested`
- `acknowledged`
- `completed`
- `failed`

这条链可以在当前 skill 环境里跑通。

## 本轮实现

### 1. `mock-supervisor-ack.sh`

新增脚本：

- `scripts/mock-supervisor-ack.sh`

用途：
- 读取 `restart-ack.supervised.json` / `restart-ack.container.json`
- 按参数把状态推进到：
  - `acknowledged`
  - `completed`
  - `failed`
- 同时写入：
  - `updated_at`
  - `result`
  - `evidence`

示例：

```bash
bash scripts/mock-supervisor-ack.sh supervised acknowledged
bash scripts/mock-supervisor-ack.sh supervised completed success
bash scripts/mock-supervisor-ack.sh supervised failed error
```

### 2. `show-restart-acks.sh`

新增脚本：

- `scripts/show-restart-acks.sh`

用途：
- 一次查看：
  - `restart-ack.container.json`
  - `restart-ack.supervised.json`
- 直接打印关键字段，便于本地检查

### 3. README 增加演示步骤

README 里现在补了本地演示 supervisor ack 闭环的命令示例，方便后续验证和给别人演示。

## 结果

这一轮之后，`container` / `supervised` 的 restart 路径第一次具备：

1. bridge 发请求
2. ack 文件落地
3. 本地示例执行器推进状态
4. connector 读取回执
5. iOS / diagnostics 展示结果

虽然这仍然是 mock 执行器，但它已经足以支撑：

- 本地演示
- 文档说明
- 回归测试
- 后续替换为真实 supervisor wrapper

## 意义

这轮不是为了“假装已经接上真实 supervisor”，而是为了把接口做成：

**今天就能完整演示，明天可以平滑替换底层执行器。**

## 后续可继续

1. 提供一个真实的 host supervisor wrapper 示例
2. 提供一个真实的 container runtime wrapper 示例
3. 把 ack/result 更新事件也接入 SSE，减少靠 refresh 才能看到变化的滞后
