# 决策日志-第24轮 真实状态源与 Token 持久化

## 背景
实际联调后确认：
- 审批链已接近真实
- 但 `/tasks` 与 `/lobsters` 仍主要来自 seed/demo 数据
- bridge 重启会导致 token 丢失，App 重新加载时表现为全部失败

这两个问题都属于产品可用性的 P0 缺口。

## 本轮目标
1. 让 skill 默认具备“真实状态源”而不是只依赖 seed
2. 让 bridge 重启后不再丢失已签发 token

## 本轮实现
### 1. Token 持久化
- 新增 `TOKENS_FILE`
- bridge 启动时恢复 token
- 签发/撤销 token 时落盘
- skill 默认路径：`runtime/auth-tokens.json`

### 2. Skill 自带 runtime state adapter
新增脚本：
- `runtime-state-adapter.sh`
- `start-runtime-adapter.sh`
- `stop-runtime-adapter.sh`
- `status-runtime-adapter.sh`

它会周期性生成：
- `runtime/runtime-state.json`
- `runtime/runtime-status.json`

并让 bridge 通过 `STATE_FILE` 默认消费该状态。

## 为什么这样做
这不是最终的“真实龙虾 runtime 私有协议接入”，但它把系统从：
- 只靠 seed 演示
推进到：
- skill 内已有独立的 runtime state producer
- bridge 真实消费外部状态文件

这样 `/tasks` 与 `/lobsters` 至少不再是 bridge 自己内置的演示状态。

## 仍未完成
- runtime adapter 目前还是 skill 内的受控示例 producer，不是最终的真实 lobster supervisor 集成
- lease 与 restart 还需要继续下放给 adapter/supervisor 真正消费
