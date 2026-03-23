#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${ROOT_DIR}/run/runtime-adapter.pid"

if [ ! -f "${PID_FILE}" ]; then
  echo "[OK] runtime adapter 当前未运行"
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
rm -f "${PID_FILE}"
echo "[OK] runtime adapter 已停止"
