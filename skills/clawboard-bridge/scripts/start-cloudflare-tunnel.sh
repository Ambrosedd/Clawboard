#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/bridge.env"
BIN_DIR="${ROOT_DIR}/runtime/bin"
BUNDLED_CLOUDFLARED="${BIN_DIR}/cloudflared"
RUN_DIR="${ROOT_DIR}/run"
LOG_DIR="${ROOT_DIR}/logs"
PID_FILE="${RUN_DIR}/cloudflare-tunnel.pid"
LOG_FILE="${LOG_DIR}/cloudflare-tunnel.log"
URL_FILE="${RUN_DIR}/cloudflare-tunnel.url"

mkdir -p "${RUN_DIR}" "${LOG_DIR}" "${ROOT_DIR}/config"

if [ -f "${CONFIG_FILE}" ]; then
  set -a
  source "${CONFIG_FILE}"
  set +a
fi

PORT="${PORT:-8787}"
TUNNEL_LOCAL_URL="${TUNNEL_LOCAL_URL:-http://127.0.0.1:${PORT}}"

CLOUDFLARED_BIN=""
if [ -x "${BUNDLED_CLOUDFLARED}" ]; then
  CLOUDFLARED_BIN="${BUNDLED_CLOUDFLARED}"
elif command -v cloudflared >/dev/null 2>&1; then
  CLOUDFLARED_BIN="$(command -v cloudflared)"
fi

if [ -z "${CLOUDFLARED_BIN}" ]; then
  echo "[ERROR] 未检测到 cloudflared。"
  echo "优先使用 skill 内自带路径: ${BUNDLED_CLOUDFLARED}"
  echo "你可以直接运行："
  echo "  bash ${ROOT_DIR}/scripts/install-cloudflared.sh"
  echo "或参考官方安装方式："
  echo "  https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
  exit 1
fi

if [ -f "${PID_FILE}" ]; then
  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" >/dev/null 2>&1; then
    echo "[OK] Cloudflare Tunnel 已在运行 (pid=${PID})"
    [ -f "${URL_FILE}" ] && echo "Tunnel URL: $(cat "${URL_FILE}")"
    exit 0
  fi
  rm -f "${PID_FILE}"
fi

rm -f "${URL_FILE}"
: > "${LOG_FILE}"
"${CLOUDFLARED_BIN}" tunnel --no-autoupdate --url "${TUNNEL_LOCAL_URL}" >"${LOG_FILE}" 2>&1 &
PID=$!
echo "${PID}" > "${PID_FILE}"

for _ in $(seq 1 30); do
  if ! kill -0 "${PID}" >/dev/null 2>&1; then
    echo "[ERROR] Cloudflare Tunnel 启动失败，请检查日志: ${LOG_FILE}"
    exit 1
  fi

  URL="$(python3 - <<'PY' "${LOG_FILE}"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(errors='ignore')
matches = re.findall(r'https://[-a-zA-Z0-9.]+trycloudflare\.com', text)
print(matches[-1] if matches else '')
PY
)"
  if [ -n "${URL}" ]; then
    printf '%s\n' "${URL}" > "${URL_FILE}"
    echo "[OK] Cloudflare Tunnel 已启动"
    echo "Tunnel URL: ${URL}"
    echo "日志: ${LOG_FILE}"
    exit 0
  fi
  sleep 1
done

echo "[ERROR] Tunnel 已启动但未在日志中识别到公网 HTTPS 地址，请检查日志: ${LOG_FILE}"
exit 1
