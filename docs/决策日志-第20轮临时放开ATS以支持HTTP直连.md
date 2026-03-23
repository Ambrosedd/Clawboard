# 决策日志-第20轮 临时放开 ATS 以支持 HTTP 直连

## 背景
当前 Clawboard 的真实连接链已经能生成公网地址，但 Bridge 仍是 HTTP 直连。iOS 的 App Transport Security (ATS) 默认拒绝非 HTTPS 请求，因此会在连接前就被系统拦截。

---

## 本轮目标
先解除当前产品可用性的硬阻塞，让 App 能连到现有 HTTP Bridge。

---

## 本轮做法
- 在 iOS 工程的生成 Info.plist 配置中加入 `NSAppTransportSecurity -> NSAllowsArbitraryLoads = YES`
- 同时作用于 Debug / Release，保证当前测试链路一致

---

## 取舍
这不是最终长期方案。

长期应收敛到：
- HTTPS
- 域名
- 反向代理 / TLS
- 或更小范围的 ATS 例外策略

但在当前阶段，如果不先放开 ATS，公网连接链即使网络通了，App 也会被系统层直接拦截。
