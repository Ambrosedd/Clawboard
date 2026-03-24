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
if [ -f "${STATUS_FILE}" ]; then
  echo "RUNTIME_STATUS: ${STATUS_FILE}"
  python3 - <<'PY' "${STATUS_FILE}"
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
try:
    data = json.loads(p.read_text())
except Exception as e:
    print(f"状态文件解析失败: {e}")
    raise SystemExit(0)
print(f"- status: {data.get('status')}")
print(f"- last_restart_requested_at: {data.get('last_restart_requested_at')}")
print(f"- last_restart_handled_at: {data.get('last_restart_handled_at')}")
print(f"- restart_execution_state: {data.get('restart_execution_state')}")
print(f"- restart_result: {data.get('restart_result')}")
print(f"- restart_evidence: {data.get('restart_evidence')}")
PY
fi
[ -f "${LOG_FILE}" ] && echo "日志: ${LOG_FILE}"
