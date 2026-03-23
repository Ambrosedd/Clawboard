#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/bridge.env"
RUNTIME_DIR="${ROOT_DIR}/runtime/connector"
RUN_DIR="${ROOT_DIR}/run"
LOG_DIR="${ROOT_DIR}/logs"
PID_FILE="${RUN_DIR}/bridge.pid"
LOG_FILE="${LOG_DIR}/bridge.log"

mkdir -p "${RUN_DIR}" "${LOG_DIR}" "${ROOT_DIR}/config"

if [ ! -f "${CONFIG_FILE}" ]; then
  cp "${ROOT_DIR}/skill.env.example" "${CONFIG_FILE}"
fi

if [ ! -f "${RUNTIME_DIR}/src/server.js" ]; then
  echo "[ERROR] bridge runtime not found: ${RUNTIME_DIR}/src/server.js"
  echo "请重新运行安装脚本，确保 connector runtime 已复制到 skill 目录。"
  exit 1
fi

if [ -f "${PID_FILE}" ]; then
  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" >/dev/null 2>&1; then
    echo "[OK] Clawboard Bridge 已在运行 (pid=${PID})"
    exit 0
  fi
  rm -f "${PID_FILE}"
fi

set -a
source "${CONFIG_FILE}"
set +a

node "${RUNTIME_DIR}/src/server.js" >>"${LOG_FILE}" 2>&1 &
PID=$!
echo "${PID}" > "${PID_FILE}"

sleep 1
if kill -0 "${PID}" >/dev/null 2>&1; then
  echo "[OK] Clawboard Bridge 已启动"
  echo "PID: ${PID}"
  echo "日志: ${LOG_FILE}"
  echo "接下来运行: bash ${ROOT_DIR}/scripts/show-connection.sh"
else
  echo "[ERROR] Clawboard Bridge 启动失败，请检查日志: ${LOG_FILE}"
  exit 1
fi
