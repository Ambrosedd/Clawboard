#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${ROOT_DIR}/run/runtime-adapter.pid"
STATE_FILE="${ROOT_DIR}/runtime/runtime-state.json"
STATUS_FILE="${ROOT_DIR}/runtime/runtime-status.json"
LOG_FILE="${ROOT_DIR}/logs/runtime-adapter.log"

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

[ -f "${STATE_FILE}" ] && echo "STATE_FILE: ${STATE_FILE}"
[ -f "${STATUS_FILE}" ] && echo "RUNTIME_STATUS: ${STATUS_FILE}"
[ -f "${LOG_FILE}" ] && echo "日志: ${LOG_FILE}"
