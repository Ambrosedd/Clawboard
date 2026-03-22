# Clawboard Pair 配对协议设计

## 1. 目标

Pair 协议用于让 iPhone App 与运行在龙虾环境中的 Clawboard Bridge 建立首次信任关系。

要求：
- 用户感知简单：安装 skill → 扫码 / 输入配对码 → 完成连接
- 不依赖中心重后端
- 默认采用一次性配对码 + 长期 token 的模式
- 后续可升级为二维码、局域网发现、云中继

---

## 2. 配对参与方

### App
负责：
- 扫码 / 输入配对码
- 发起配对交换
- 存储长期 token

### Bridge Sidecar
负责：
- 生成一次性配对会话
- 校验配对码
- 发放长期 token
- 建立 App 与本地节点的信任关系

### Lobster Skill
负责：
- 启动 bridge
- 向用户展示配对码 / 二维码
- 提供“重新生成配对码”“撤销配对”等入口

---

## 3. 推荐流程

```text
1. 用户安装并启用 Clawboard skill
2. skill 拉起 bridge
3. bridge 生成一次性 pair session
4. 用户在终端 / 控制台中看到 pair code 或二维码
5. App 输入或扫码得到：host + pair_code + node_id
6. App 调用 /pair/exchange
7. bridge 返回长期 token + 节点信息
8. App 保存 token，后续使用 Bearer Token 访问 API
```

---

## 4. 会话模型

### Pair Session
字段建议：
- `pairing_id`: 一次性配对会话 ID
- `pair_code`: 短码，供用户输入或二维码携带
- `expires_at`: 到期时间
- `node_id`: 节点 ID
- `bridge_version`: bridge 版本
- `display_name`: 展示名称
- `network_hint`: 供 App 展示的网络提示

示例：
```json
{
  "pairing_id": "pair-001",
  "pair_code": "LX-472911",
  "expires_at": "2026-03-22T15:30:00Z",
  "node_id": "node-local-1",
  "display_name": "MacBook-Pro / 分析龙虾节点",
  "bridge_version": "0.2.0",
  "network_hint": "direct"
}
```

---

## 5. 接口设计

### GET /pair/session
获取当前一次性配对会话。

响应示例：
```json
{
  "pairing_id": "pair-001",
  "pair_code": "LX-472911",
  "expires_at": "2026-03-22T15:30:00Z",
  "node_id": "node-local-1",
  "display_name": "MacBook-Pro / 分析龙虾节点",
  "bridge_version": "0.2.0",
  "network_hint": "direct"
}
```

### POST /pair/exchange
App 用配对码换长期 token。

请求体：
```json
{
  "pair_code": "LX-472911",
  "device_name": "iPhone 16 Pro",
  "client_name": "Clawboard iOS",
  "client_version": "0.1.0"
}
```

成功响应：
```json
{
  "token": "cb_live_xxx",
  "token_type": "Bearer",
  "issued_at": "2026-03-22T15:01:00Z",
  "node": {
    "id": "node-local-1",
    "name": "MacBook-Pro",
    "platform": "linux"
  }
}
```

失败响应：
```json
{
  "error": {
    "code": "pair_code_invalid",
    "message": "pair code is invalid or expired"
  }
}
```

---

## 6. Token 模型

当前阶段建议：
- 首先使用 bridge 本地生成并保存的长期 token
- App 首次 exchange 后持有 token
- 后续所有 API 请求带 `Authorization: Bearer <token>`

后续可升级：
- token 撤销
- 多设备 token 管理
- token scope
- refresh token

---

## 7. 安全边界

### 当前原则
- pair code 必须是短期一次性凭据
- pair code 过期后不可复用
- token 与 pair code 不是同一种东西
- token 仅用于访问受控 bridge API
- token 默认不代表任意 shell / 任意系统权限

### 建议约束
- 配对码 TTL：5~10 分钟
- 配对成功后自动失效
- 支持手动重新生成
- 支持撤销已配对设备

---

## 8. 产品表达建议

对用户展示时建议使用：
- 扫码配对
- 输入配对码
- 连接此龙虾节点

尽量不要让用户接触：
- connector
- bridge token internals
- runtime adapter

---

## 9. 当前阶段结论

当前第一版 Pair 协议应优先覆盖：
- 单节点
- 一次性配对码
- 长期 Bearer Token
- 手动输入配对码

二维码扫描、局域网发现、多设备撤销、云中继，属于后续增强项。
