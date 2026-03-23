# 安装与连接（前期方案）

当前版本还没进入官方 skill 库，因此前期采用：

1. **仓库内可交付 skill bundle** 作为安装源
2. **一键安装脚本** 负责把 skill + bridge runtime 一起装好
3. **App 中“添加龙虾”入口** 完成配对

## 快速安装

### 方式 1：在仓库里本地执行

```bash
cd install
bash install-clawboard-bridge.sh
cd ~/.clawboard/skills/clawboard-bridge
bash scripts/start-bridge.sh
bash scripts/show-connection.sh
```

### 方式 2：直接复制一键安装命令给龙虾执行

```bash
curl -fsSL https://raw.githubusercontent.com/Ambrosedd/Clawboard/main/install/bootstrap-clawboard-bridge.sh | bash
```

也可以只给龙虾下载链接：

```text
https://raw.githubusercontent.com/Ambrosedd/Clawboard/main/install/bootstrap-clawboard-bridge.sh
```

安装完成后：

```bash
cd ~/.clawboard/skills/clawboard-bridge
bash scripts/start-bridge.sh
bash scripts/show-connection.sh
```

安装脚本当前会：
- 把 `skills/clawboard-bridge/` 复制到本地安装目录
- 同时复制 `connector/` 运行时到 skill bundle 内
- 生成默认配置、日志目录、运行目录
- 提供 `start-bridge.sh / stop-bridge.sh / status-bridge.sh / show-connection.sh`
- 输出可直接发给手机的连接串

## 当前定位

这不是最终官方 skill 库分发形态，而是前期为了尽快跑通：
- 安装
- 启动
- 配对
- 连接

但它已经不再只是说明型目录，而是一个可交付的前期 skill bundle。

后续建议收敛到：
- 官方 skill 库
- 或 `lobster skill install clawboard-bridge`
- 或 `lobster mobile enable`

## 当前更接近真实接入的方式

如果你的本地 runtime / skill / sidecar 已经能输出标准 JSON 状态快照，
当前可以先让 Bridge 读取该文件，而不是继续只用内置 seed 数据：

```bash
cd connector
STATE_FILE=./sample-runtime-state.json node src/server.js
```

这是一种很适合当前阶段的中间态：
- runtime 负责采集真实状态
- Bridge 负责配对、鉴权、统一 API、SSE 事件流
- App 不需要知道底层数据到底来自种子数据还是外部状态文件
