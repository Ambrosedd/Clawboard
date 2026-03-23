# 决策日志-第22轮 Cloudflare Tunnel 公网 HTTPS 接入

## 背景
在公网 IP + HTTP 方案下，iOS 会持续受到 ATS 限制。即使临时放开 ATS，也不是最终产品方案。

用户明确选择“方案二”，即优先采用 Cloudflare Tunnel 这类 HTTPS 隧道，把本地 bridge 暴露为公网 HTTPS 地址。

---

## 本轮结论
将公网连接主路径调整为：

1. 本地启动 bridge
2. 启动 Cloudflare Tunnel
3. 自动拿到 `https://*.trycloudflare.com` 地址
4. `show-connection.sh` 优先输出 HTTPS 配对串
5. App 直接使用 HTTPS 配对，不再依赖 HTTP 公网 IP

---

## 为什么这么做
相较于继续围绕 ATS 打补丁，Tunnel 方案更接近一步到位：
- 对 iOS 来说是原生接受的 HTTPS
- 不要求用户自己先配 Nginx / Caddy / 证书
- 不要求暴露机器公网监听端口
- 不再把产品入口建立在 `http://IP:8787` 上

---

## 当前实现
skill 新增：
- `start-cloudflare-tunnel.sh`
- `stop-cloudflare-tunnel.sh`
- `status-cloudflare-tunnel.sh`

并让 `show-connection.sh`：
- 优先读取 tunnel 生成的 HTTPS URL
- 再生成最终的 `clawboard://pair?...&url=https://...` 连接串

---

## 当前限制
- 依赖本机安装 `cloudflared`
- 当前默认是 quick tunnel / trycloudflare 路径，适合前期验证与早期用户使用
- 若后续进入正式生产形态，仍建议收敛到域名 + 固定 tunnel / 反代配置
