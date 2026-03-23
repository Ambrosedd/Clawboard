#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/bridge.env"
STATE_FILE_DEFAULT="${ROOT_DIR}/runtime/runtime-state.json"
LEASES_FILE="${ROOT_DIR}/runtime/capability-leases.json"
RESTART_SIGNAL_FILE="${ROOT_DIR}/runtime/restart-requested.flag"
STATUS_FILE="${ROOT_DIR}/runtime/runtime-status.json"
LOG_FILE="${ROOT_DIR}/logs/runtime-adapter.log"

mkdir -p "${ROOT_DIR}/runtime" "${ROOT_DIR}/logs" "${ROOT_DIR}/config"

if [ -f "${CONFIG_FILE}" ]; then
  set -a
  source "${CONFIG_FILE}"
  set +a
fi

STATE_FILE="${STATE_FILE:-${STATE_FILE_DEFAULT}}"
NODE_ID="${NODE_ID:-node-local-1}"
CONNECTOR_NAME="${CONNECTOR_NAME:-Clawboard Bridge}"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LEASE_COUNT=0
LEASE_SCOPE=""
LOBSTER_STATUS="running"
TASK_STATUS="running"
TASK_STEP="collect_context"
TASK_PROGRESS=38
TASK_TITLE="真实运行任务"
TASK_INPUT="由 runtime adapter 生成的真实状态快照"
TASK_OUTPUT=""
TASK_ERROR=""
RISK_LEVEL="medium"
RISK_SCORE=48
ALERT_TITLE=""
ALERT_SUMMARY=""
ALERT_LEVEL=""
RESTART_PENDING=false

if [ -f "${LEASES_FILE}" ]; then
  LEASE_COUNT="$(python3 - <<'PY' "${LEASES_FILE}"
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])
try:
    data=json.loads(p.read_text())
    items=data.get('items') or []
    print(len(items))
except Exception:
    print(0)
PY
)"
  LEASE_SCOPE="$(python3 - <<'PY' "${LEASES_FILE}"
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])
try:
    data=json.loads(p.read_text())
    items=data.get('items') or []
    print((items[0].get('granted_scope') if items else '') or '')
except Exception:
    print('')
PY
)"
fi

if [ "${LEASE_COUNT}" -gt 0 ]; then
  LOBSTER_STATUS="busy"
  TASK_STATUS="running"
  TASK_STEP="temporary_capability_active"
  TASK_PROGRESS=72
  TASK_TITLE="临时授权执行中"
  TASK_INPUT="已读取 capability lease"
  TASK_OUTPUT="当前权限范围：${LEASE_SCOPE}"
fi

if [ -f "${RESTART_SIGNAL_FILE}" ]; then
  RESTART_PENDING=true
  LOBSTER_STATUS="restarting"
  TASK_STATUS="running"
  TASK_STEP="restart_runtime"
  TASK_PROGRESS=83
  ALERT_TITLE="龙虾正在重启"
  ALERT_SUMMARY="runtime adapter 检测到重启请求，已进入受限重启流程"
  ALERT_LEVEL="P2"
  cat > "${STATUS_FILE}" <<EOF
{
  "last_restart_requested_at": "${NOW}",
  "last_restart_handled_at": "${NOW}",
  "status": "restart_requested"
}
EOF
fi

TMP_FILE="${STATE_FILE}.tmp"
python3 - <<'PY' "${TMP_FILE}" "${NOW}" "${NODE_ID}" "${LEASE_COUNT}" "${LEASE_SCOPE}" "${LOBSTER_STATUS}" "${TASK_STATUS}" "${TASK_STEP}" "${TASK_PROGRESS}" "${TASK_TITLE}" "${TASK_INPUT}" "${TASK_OUTPUT}" "${TASK_ERROR}" "${RISK_LEVEL}" "${RISK_SCORE}" "${ALERT_TITLE}" "${ALERT_SUMMARY}" "${ALERT_LEVEL}"
import json, sys
out, now, node_id, lease_count, lease_scope, lobster_status, task_status, task_step, task_progress, task_title, task_input, task_output, task_error, risk_level, risk_score, alert_title, alert_summary, alert_level = sys.argv[1:]
lease_count = int(lease_count)
task_progress = int(task_progress)
risk_score = int(risk_score)
state = {
  "schema_version": "clawboard.bridge.state.v1",
  "generated_at": now,
  "lobsters": [
    {
      "id": "lobster-runtime-1",
      "name": "Runtime Lobster",
      "status": lobster_status,
      "task_title": task_title,
      "last_active_at": now,
      "risk_level": risk_level,
      "node_id": node_id,
      "recent_logs": [
        "runtime state adapter active",
        f"active_leases={lease_count}",
        (f"granted_scope={lease_scope}" if lease_scope else "no active granted scope")
      ]
    }
  ],
  "tasks": [
    {
      "id": "task-runtime-1",
      "title": task_title,
      "status": task_status,
      "progress": task_progress,
      "lobster_id": "lobster-runtime-1",
      "current_step": task_step,
      "risk_level": risk_level,
      "risk_score": risk_score,
      "input_summary": task_input,
      "output_summary": task_output or None,
      "error_reason": task_error or None,
      "timeline": [
        {"step": "collect_context", "status": "done"},
        {"step": task_step, "status": "in_progress"}
      ]
    }
  ],
  "approvals": [],
  "alerts": []
}
if alert_title and alert_summary and alert_level:
    state["alerts"].append({
      "id": "alert-runtime-restart",
      "level": alert_level,
      "title": alert_title,
      "summary": alert_summary,
      "related_type": "task",
      "related_id": "task-runtime-1"
    })
with open(out, 'w', encoding='utf-8') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
PY
mv "${TMP_FILE}" "${STATE_FILE}"

if [ -f "${RESTART_SIGNAL_FILE}" ]; then
  rm -f "${RESTART_SIGNAL_FILE}"
fi

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] runtime state refreshed -> ${STATE_FILE}" >> "${LOG_FILE}"
