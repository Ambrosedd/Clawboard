# 决策日志-第23轮 将 Cloudflare 纳入 Skill 交付

## 背景
此前虽然已经验证 Cloudflare Tunnel 方案可行，但 `cloudflared` 仍依赖人工在宿主机环境中单独安装，不算真正进入 skill 交付链。

## 本轮目标
把 Cloudflare Tunnel 从“人工环境依赖”推进为“skill 自带可安装能力”。

## 本轮落地
- skill 新增 `scripts/install-cloudflared.sh`
- 默认安装位置：`runtime/bin/cloudflared`
- `start-cloudflare-tunnel.sh` 优先使用 skill 自带二进制
- 若不存在，再 fallback 到系统 PATH 中的 `cloudflared`
- 若两者都不存在，脚本会明确提示用户先执行 `install-cloudflared.sh`

## 价值
这样做之后，用户视角不再是：
- 你先想办法把 cloudflared 装到机器里

而是：
- 装好 skill
- 运行 skill 自带安装脚本
- 直接起 HTTPS tunnel

## 仍然保留的现实限制
- 当前默认仍使用 quick tunnel / trycloudflare 域名，适合前期验证与早期用户
- 如果进入正式商用，仍建议后续收敛到固定 tunnel 或自有域名入口
