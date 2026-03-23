#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/bridge.env"
PID_FILE="${ROOT_DIR}/run/bridge.pid"
LOG_FILE="${ROOT_DIR}/logs/bridge.log"

if [ -f "${CONFIG_FILE}" ]; then
  set -a
  source "${CONFIG_FILE}"
  set +a
fi

PORT="${PORT:-8787}"
PUBLIC_PROTOCOL="${PUBLIC_PROTOCOL:-http}"
PUBLIC_HOST="${PUBLIC_HOST:-127.0.0.1}"
BASE_URL="${PUBLIC_BASE_URL:-${PUBLIC_PROTOCOL}://${PUBLIC_HOST}:${PORT}}"

echo "Bridge URL: ${BASE_URL}"

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

if [ -f "${LOG_FILE}" ]; then
  echo "日志: ${LOG_FILE}"
fi

if command -v curl >/dev/null 2>&1; then
  echo
  echo "Health:"
  curl -fsS "${BASE_URL}/health" || echo "无法访问 /health"
fi
