# 安装与连接（前期方案）

当前版本还没进入官方 skill 库，因此前期采用：

1. **仓库内 skill 目录** 作为安装源
2. **一键安装脚本** 降低操作门槛
3. **App 中“添加龙虾”入口** 完成配对

## 快速安装

```bash
cd install
bash install-clawboard-bridge.sh
```

安装脚本当前会：
- 把 `skills/clawboard-bridge/` 复制到本地安装目录
- 输出建议的 Bridge 地址与默认配对码
- 提示下一步去 App 中完成“添加龙虾”

## 当前定位

这不是最终官方分发形态，而是前期为了尽快跑通：
- 安装
- 启用
- 配对
- 连接

后续建议收敛到：
- 官方 skill 库
- 或 `lobster skill install clawboard-bridge`
- 或 `lobster mobile enable`
