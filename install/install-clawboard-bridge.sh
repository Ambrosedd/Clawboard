#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="clawboard-bridge"
INSTALL_ROOT="${CLAWBOARD_INSTALL_ROOT:-$HOME/.clawboard}"
SKILL_SOURCE_DIR="${CLAWBOARD_SKILL_SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/${SKILL_NAME}" && pwd)}"
TARGET_SKILL_DIR="${INSTALL_ROOT}/skills/${SKILL_NAME}"
BRIDGE_PORT="${CLAWBOARD_BRIDGE_PORT:-8787}"
PAIR_CODE="${CLAWBOARD_PAIR_CODE:-LX-472911}"

cat <<EOF
==> Clawboard Bridge 安装向导（骨架版）
安装根目录: ${INSTALL_ROOT}
skill 来源目录: ${SKILL_SOURCE_DIR}
目标目录: ${TARGET_SKILL_DIR}
EOF

mkdir -p "${INSTALL_ROOT}/skills"
rm -rf "${TARGET_SKILL_DIR}"
cp -R "${SKILL_SOURCE_DIR}" "${TARGET_SKILL_DIR}"

cat <<EOF

[OK] 已安装 skill: ${SKILL_NAME}

BRIDGE_HOST="$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'your-server-ip')"
PAIRING_LINK="clawboard://pair?code=${PAIR_CODE}&url=http://${BRIDGE_HOST}:${BRIDGE_PORT}"

cat <<EOF

[OK] 已安装 skill: ${SKILL_NAME}

下一步建议：
1. 在你的龙虾环境中启用该 skill
2. 启动本地 bridge / sidecar
3. 把下面这段“连接串”复制或直接发到手机
4. 在 Clawboard App → 设置 → 添加龙虾 中直接粘贴（App 也会尝试自动读取剪贴板）

   连接串: ${PAIRING_LINK}

手动兜底（仅调试时再用）：
   配对码: ${PAIR_CODE}
   Bridge 地址: http://${BRIDGE_HOST}:${BRIDGE_PORT}

说明：
- 这是前期骨架安装脚本，用于快速分发 skill
- 未来应收敛为 lobster 自带安装命令或官方 skill 仓库安装
EOF
