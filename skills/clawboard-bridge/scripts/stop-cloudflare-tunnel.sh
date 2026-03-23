#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${ROOT_DIR}/run/cloudflare-tunnel.pid"
URL_FILE="${ROOT_DIR}/run/cloudflare-tunnel.url"

if [ ! -f "${PID_FILE}" ]; then
  echo "[OK] Cloudflare Tunnel 当前未运行"
  rm -f "${URL_FILE}"
  exit 0
fi

PID="$(cat "${PID_FILE}")"
if kill -0 "${PID}" >/dev/null 2>&1; then
  kill "${PID}" || true
  sleep 1
  if kill -0 "${PID}" >/dev/null 2>&1; then
    kill -9 "${PID}" >/dev/null 2>&1 || true
  fi
fi

rm -f "${PID_FILE}" "${URL_FILE}"
echo "[OK] Cloudflare Tunnel 已停止"
