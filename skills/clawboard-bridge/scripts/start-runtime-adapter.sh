#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="${ROOT_DIR}/run"
LOG_DIR="${ROOT_DIR}/logs"
PID_FILE="${RUN_DIR}/runtime-adapter.pid"
LOG_FILE="${LOG_DIR}/runtime-adapter.log"
SCRIPT_FILE="${ROOT_DIR}/scripts/runtime-state-adapter.sh"
INTERVAL="${RUNTIME_ADAPTER_INTERVAL_SECONDS:-5}"

mkdir -p "${RUN_DIR}" "${LOG_DIR}"

if [ -f "${PID_FILE}" ]; then
  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" >/dev/null 2>&1; then
    echo "[OK] runtime adapter 已在运行 (pid=${PID})"
    exit 0
  fi
  rm -f "${PID_FILE}"
fi

(
  while true; do
    bash "${SCRIPT_FILE}" >> "${LOG_FILE}" 2>&1 || true
    sleep "${INTERVAL}"
  done
) &
PID=$!
echo "${PID}" > "${PID_FILE}"
echo "[OK] runtime adapter 已启动 (pid=${PID})"
