#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/bridge.env"
TUNNEL_URL_FILE="${ROOT_DIR}/run/cloudflare-tunnel.url"

if [ -f "${CONFIG_FILE}" ]; then
  set -a
  source "${CONFIG_FILE}"
  set +a
fi

detect_public_host() {
  if [ -n "${PUBLIC_HOST:-}" ]; then
    printf '%s\n' "${PUBLIC_HOST}"
    return 0
  fi

  local ip=""
  if command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  if [ -z "${ip}" ] && command -v ip >/dev/null 2>&1; then
    ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
  fi
  if [ -z "${ip}" ] && command -v python3 >/dev/null 2>&1; then
    ip="$(python3 - <<'PY'
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(('1.1.1.1', 80))
    print(s.getsockname()[0])
finally:
    s.close()
PY
)"
  fi

  if [ -z "${ip}" ]; then
    ip="127.0.0.1"
  fi
  printf '%s\n' "${ip}"
}

PORT="${PORT:-8787}"
PAIR_CODE="${PAIR_CODE:-LX-472911}"
PUBLIC_PROTOCOL="${PUBLIC_PROTOCOL:-http}"
PUBLIC_HOST="$(detect_public_host)"
BASE_URL="${PUBLIC_BASE_URL:-${PUBLIC_PROTOCOL}://${PUBLIC_HOST}:${PORT}}"

if [ -f "${TUNNEL_URL_FILE}" ]; then
  TUNNEL_URL="$(cat "${TUNNEL_URL_FILE}")"
  if [ -n "${TUNNEL_URL}" ]; then
    BASE_URL="${TUNNEL_URL}"
  fi
fi

if command -v curl >/dev/null 2>&1; then
  SESSION_JSON="$(curl -fsS "${BASE_URL}/pair/session" 2>/dev/null || true)"
  if [ -n "${SESSION_JSON}" ]; then
    PAIRING_LINK="$(printf '%s' "${SESSION_JSON}" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("pairing_link") or "")' 2>/dev/null || true)"
    DISPLAY_NAME="$(printf '%s' "${SESSION_JSON}" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("display_name") or "")' 2>/dev/null || true)"
    EXPIRES_AT="$(printf '%s' "${SESSION_JSON}" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("expires_at") or "")' 2>/dev/null || true)"
    BRIDGE_URL="$(printf '%s' "${SESSION_JSON}" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("bridge_url") or "")' 2>/dev/null || true)"
    [ -n "${BRIDGE_URL}" ] && BASE_URL="${BRIDGE_URL}"
    if [ -n "${PAIRING_LINK}" ]; then
      echo "节点: ${DISPLAY_NAME:-Clawboard Bridge}"
      echo "Bridge 地址: ${BASE_URL}"
      [ -n "${EXPIRES_AT}" ] && echo "过期时间: ${EXPIRES_AT}"
      echo
      echo "把这段连接串发给手机："
      echo "${PAIRING_LINK}"
      exit 0
    fi
  fi
fi

ENCODED_URL="$(python3 -c 'import os, urllib.parse; print(urllib.parse.quote(os.environ["BASE_URL"], safe=""))' BASE_URL="${BASE_URL}")"
ENCODED_CODE="$(python3 -c 'import os, urllib.parse; print(urllib.parse.quote(os.environ["PAIR_CODE"], safe=""))' PAIR_CODE="${PAIR_CODE}")"
PAIRING_LINK="clawboard://pair?code=${ENCODED_CODE}&url=${ENCODED_URL}"

echo "节点: Clawboard Bridge"
echo "Bridge 地址: ${BASE_URL}"
if [ -f "${TUNNEL_URL_FILE}" ]; then
  echo "连接模式: Cloudflare Tunnel (HTTPS)"
else
  echo "连接模式: Direct"
fi
echo
echo "把这段连接串发给手机："
echo "${PAIRING_LINK}"
