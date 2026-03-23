#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/bridge.env"

if [ -f "${CONFIG_FILE}" ]; then
  set -a
  source "${CONFIG_FILE}"
  set +a
fi

PORT="${PORT:-8787}"
PAIR_CODE="${PAIR_CODE:-LX-472911}"
PUBLIC_PROTOCOL="${PUBLIC_PROTOCOL:-http}"
PUBLIC_HOST="${PUBLIC_HOST:-127.0.0.1}"
BASE_URL="${PUBLIC_BASE_URL:-${PUBLIC_PROTOCOL}://${PUBLIC_HOST}:${PORT}}"

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
echo
echo "把这段连接串发给手机："
echo "${PAIRING_LINK}"
