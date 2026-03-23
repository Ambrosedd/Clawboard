#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="clawboard-bridge"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_ROOT="${CLAWBOARD_INSTALL_ROOT:-$HOME/.clawboard}"
SKILL_SOURCE_DIR="${CLAWBOARD_SKILL_SOURCE_DIR:-${REPO_ROOT}/skills/${SKILL_NAME}}"
CONNECTOR_SOURCE_DIR="${CLAWBOARD_CONNECTOR_SOURCE_DIR:-${REPO_ROOT}/connector}"
TARGET_SKILL_DIR="${INSTALL_ROOT}/skills/${SKILL_NAME}"
BRIDGE_PORT="${CLAWBOARD_BRIDGE_PORT:-8787}"
PAIR_CODE="${CLAWBOARD_PAIR_CODE:-LX-472911}"

cat <<EOF
==> Clawboard Bridge 安装向导（前期可交付版）
安装根目录: ${INSTALL_ROOT}
skill 来源目录: ${SKILL_SOURCE_DIR}
目标目录: ${TARGET_SKILL_DIR}
EOF

mkdir -p "${INSTALL_ROOT}/skills"
rm -rf "${TARGET_SKILL_DIR}"
cp -R "${SKILL_SOURCE_DIR}" "${TARGET_SKILL_DIR}"
mkdir -p "${TARGET_SKILL_DIR}/runtime"
cp -R "${CONNECTOR_SOURCE_DIR}" "${TARGET_SKILL_DIR}/runtime/connector"
mkdir -p "${TARGET_SKILL_DIR}/config" "${TARGET_SKILL_DIR}/logs" "${TARGET_SKILL_DIR}/run"

CONFIG_FILE="${TARGET_SKILL_DIR}/config/bridge.env"
cp "${TARGET_SKILL_DIR}/skill.env.example" "${CONFIG_FILE}"
sed -i "s/^PORT=.*/PORT=${BRIDGE_PORT}/" "${CONFIG_FILE}"
sed -i "s/^PAIR_CODE=.*/PAIR_CODE=${PAIR_CODE}/" "${CONFIG_FILE}"
BRIDGE_HOST="$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'your-server-ip')"
sed -i "s/^PUBLIC_HOST=.*/PUBLIC_HOST=${BRIDGE_HOST}/" "${CONFIG_FILE}"
PAIRING_LINK="clawboard://pair?code=${PAIR_CODE}&url=http://${BRIDGE_HOST}:${BRIDGE_PORT}"

cat <<EOF

[OK] 已安装 skill: ${SKILL_NAME}

下一步建议：
1. 进入 skill 目录：
   cd ${TARGET_SKILL_DIR}
2. 启动 bridge：
   bash scripts/start-bridge.sh
3. 如需公网 HTTPS 连接，先安装并启动 tunnel：
   bash scripts/install-cloudflared.sh
   bash scripts/start-cloudflare-tunnel.sh
4. 查看连接串：
   bash scripts/show-connection.sh
5. 在 Clawboard App → 设置 → 添加龙虾 中直接粘贴（App 也会尝试自动读取剪贴板）

预设连接串（bridge 启动后也会以运行中的真实 session 为准）：
   ${PAIRING_LINK}

手动兜底（仅调试时再用）：
   配对码: ${PAIR_CODE}
   Bridge 地址: http://${BRIDGE_HOST}:${BRIDGE_PORT}

说明：
- 这是前期可交付 skill bundle
- 安装脚本会同时复制 skill 与 bridge runtime
- 未来应收敛为 lobster 自带安装命令或官方 skill 仓库安装
EOF
