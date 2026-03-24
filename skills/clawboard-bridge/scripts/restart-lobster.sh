#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/runtime"
RESTART_FLAG="${RUNTIME_DIR}/restart-requested.flag"

mkdir -p "${RUNTIME_DIR}"
REQUEST_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REQUEST_ID="restart-$(date +%s)"
cat > "${RESTART_FLAG}" <<EOF
{
  "request_id": "${REQUEST_ID}",
  "reason": "manual_skill_script",
  "time": "${REQUEST_TIME}",
  "requested_by": "clawboard_skill"
}
EOF

echo "[OK] 已写入重启请求标记: ${RESTART_FLAG}"
echo "request_id: ${REQUEST_ID}"
echo "requested_at: ${REQUEST_TIME}"
echo "如果你的龙虾 supervisor 已接入该标记文件，它会执行受限重启。"
