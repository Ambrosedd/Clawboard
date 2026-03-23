#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/runtime"
RESTART_FLAG="${RUNTIME_DIR}/restart-requested.flag"

mkdir -p "${RUNTIME_DIR}"
cat > "${RESTART_FLAG}" <<EOF
{
  "reason": "manual_skill_script",
  "time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "[OK] 已写入重启请求标记: ${RESTART_FLAG}"
echo "如果你的龙虾 supervisor 已接入该标记文件，它会执行受限重启。"
