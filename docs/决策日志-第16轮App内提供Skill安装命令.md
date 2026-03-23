# 决策日志-第16轮 App 内提供 Skill 安装命令

## 背景
用户希望不只是“仓库里有 skill”，而是：

- App 里直接给出 skill 下载链接
- App 里直接给出一键安装命令
- 用户复制后直接喂给自己的龙虾执行
- 龙虾能完成 `clawboard-bridge` skill 安装

这意味着 Clawboard 的产品路径需要进一步从“面向开发者的仓库说明”转向“面向用户的可复制命令”。

---

## 本轮目标
把安装 skill 这一步收敛为：

> 在 App 里复制安装命令 → 发给龙虾执行 → 龙虾安装 skill → 返回连接串 → App 连接

---

## 本轮做法

### 1. 增加 bootstrap 安装脚本
新增：
- `install/bootstrap-clawboard-bridge.sh`

作用：
- 从 GitHub 仓库下载当前分支归档
- 解压后调用 `install/install-clawboard-bridge.sh`
- 完成前期 skill bundle 安装

### 2. App 直接展示两类内容
在“添加龙虾”页直接展示：
- 下载链接
- 一键安装命令

并提供：
- 复制下载链接
- 复制安装命令

### 3. 用户路径更新
用户现在不需要先去翻仓库文档，而可以直接：
1. 在 App 里复制安装命令
2. 发给龙虾执行
3. 再让龙虾运行 start/show 命令
4. 把连接串粘贴回 App

---

## 当前结论
这一轮的价值，在于把“skill 分发”从代码仓库动作推进成了 App 内可直接触发的用户动作。
