#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${ROOT_DIR}/run/cloudflare-tunnel.pid"
URL_FILE="${ROOT_DIR}/run/cloudflare-tunnel.url"
LOG_FILE="${ROOT_DIR}/logs/cloudflare-tunnel.log"

if [ -f "${PID_FILE}" ]; then
  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" >/dev/null 2>&1; then
    echo "状态: running (pid=${PID})"
  else
    echo "状态: stale pid file (pid=${PID})"
  fi
else
  echo "状态: stopped"
fi

if [ -f "${URL_FILE}" ]; then
  echo "Tunnel URL: $(cat "${URL_FILE}")"
fi

if [ -f "${LOG_FILE}" ]; then
  echo "日志: ${LOG_FILE}"
fi
