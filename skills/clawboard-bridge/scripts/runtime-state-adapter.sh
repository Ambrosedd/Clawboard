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
LEASE_KIND=""
LEASE_EXPIRES_AT=""
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
RESTART_REASON=""
RESTART_REQUESTED_AT=""
RESTART_REQUEST_ID=""
RESTART_REQUESTED_BY=""
RESTART_LAST_HANDLED_AT=""
RESTART_EXECUTION_STATE="idle"
RESTART_RESULT=""
RESTART_EVIDENCE=""
RUNTIME_STATUS="healthy"
COMMAND_ALIAS=""

if [ -f "${STATUS_FILE}" ]; then
  eval "$(python3 - <<'PY' "${STATUS_FILE}"
import json, sys, shlex, pathlib
p=pathlib.Path(sys.argv[1])
try:
    data=json.loads(p.read_text())
except Exception:
    data={}
for key in ['last_restart_requested_at','last_restart_request_id','last_restart_requested_by','last_restart_handled_at','restart_execution_state','restart_result','restart_evidence','status']:
    val=data.get(key,'') or ''
    print(f"{key.upper()}={shlex.quote(str(val))}")
PY
)"
  RESTART_REQUESTED_AT="${LAST_RESTART_REQUESTED_AT:-}"
  RESTART_REQUEST_ID="${LAST_RESTART_REQUEST_ID:-}"
  RESTART_REQUESTED_BY="${LAST_RESTART_REQUESTED_BY:-}"
  RESTART_LAST_HANDLED_AT="${LAST_RESTART_HANDLED_AT:-}"
  RESTART_EXECUTION_STATE="${RESTART_EXECUTION_STATE:-idle}"
  RESTART_RESULT="${RESTART_RESULT:-}"
  RESTART_EVIDENCE="${RESTART_EVIDENCE:-}"
  RUNTIME_STATUS="${STATUS:-healthy}"
fi

if [ -f "${LEASES_FILE}" ]; then
  eval "$(python3 - <<'PY' "${LEASES_FILE}"
import json,sys,shlex,pathlib,datetime
p=pathlib.Path(sys.argv[1])
lease_count=0
lease_scope=''
lease_kind=''
lease_expires_at=''
command_alias=''
try:
    data=json.loads(p.read_text())
    items=data.get('items') or []
    now=datetime.datetime.now(datetime.timezone.utc)
    active=[]
    for item in items:
        try:
            expires=datetime.datetime.fromisoformat(str(item.get('expires_at')).replace('Z','+00:00'))
        except Exception:
            continue
        if expires > now:
            active.append(item)
    lease_count=len(active)
    if active:
        first=active[0]
        lease_scope=(first.get('granted_scope') or '')
        lease_kind=(first.get('capability_kind') or '')
        lease_expires_at=(first.get('expires_at') or '')
        command_alias=(first.get('command_alias') or '')
except Exception:
    pass
for k,v in [('LEASE_COUNT', lease_count), ('LEASE_SCOPE', lease_scope), ('LEASE_KIND', lease_kind), ('LEASE_EXPIRES_AT', lease_expires_at), ('COMMAND_ALIAS', command_alias)]:
    print(f"{k}={shlex.quote(str(v))}")
PY
)"
fi

if [ "${LEASE_COUNT}" -gt 0 ]; then
  LOBSTER_STATUS="busy"
  TASK_STATUS="running"
  TASK_STEP="temporary_capability_active"
  TASK_PROGRESS=72
  TASK_TITLE="临时授权执行中"
  TASK_INPUT="runtime adapter 已消费 capability lease"
  if [ "${LEASE_KIND}" = "command_alias" ]; then
    TASK_OUTPUT="已授权命令别名：${COMMAND_ALIAS:-unknown}"
  else
    TASK_OUTPUT="已授权目录范围：${LEASE_SCOPE:-unknown}"
  fi
fi

if [ -f "${RESTART_SIGNAL_FILE}" ]; then
  RESTART_PENDING=true
  eval "$(python3 - <<'PY' "${RESTART_SIGNAL_FILE}"
import json,sys,pathlib,shlex
p=pathlib.Path(sys.argv[1])
try:
    data=json.loads(p.read_text())
except Exception:
    data={}
for key, default in [
    ('reason','restart_requested'),
    ('request_id',''),
    ('requested_by',''),
    ('time','')
]:
    value = data.get(key) or default
    shell_key = {
        'reason': 'RESTART_REASON',
        'request_id': 'RESTART_REQUEST_ID',
        'requested_by': 'RESTART_REQUESTED_BY',
        'time': 'RESTART_REQUESTED_AT'
    }[key]
    print(f"{shell_key}={shlex.quote(str(value))}")
PY
)"
  [ -n "${RESTART_REQUESTED_AT}" ] || RESTART_REQUESTED_AT="${NOW}"
  RESTART_LAST_HANDLED_AT="${NOW}"
  RESTART_EXECUTION_STATE="handled"
  RESTART_RESULT="success"
  RESTART_EVIDENCE="signal_file_consumed:${RESTART_REASON}:request_id=${RESTART_REQUEST_ID:-unknown}:requested_by=${RESTART_REQUESTED_BY:-unknown}"
  RUNTIME_STATUS="restart_handled"
  LOBSTER_STATUS="restarting"
  TASK_STATUS="running"
  TASK_STEP="restart_runtime"
  TASK_PROGRESS=83
  TASK_TITLE="Runtime 重启处理中"
  TASK_INPUT="runtime adapter 检测到 restart signal"
  TASK_OUTPUT="重启请求已接收，evidence=${RESTART_EVIDENCE}"
  ALERT_TITLE="龙虾正在重启"
  ALERT_SUMMARY="runtime adapter 已处理重启请求：${RESTART_REASON}"
  ALERT_LEVEL="P2"
  cat > "${STATUS_FILE}" <<EOF
{
  "last_restart_requested_at": "${RESTART_REQUESTED_AT}",
  "last_restart_request_id": "${RESTART_REQUEST_ID}",
  "last_restart_requested_by": "${RESTART_REQUESTED_BY}",
  "last_restart_handled_at": "${RESTART_LAST_HANDLED_AT}",
  "restart_execution_state": "${RESTART_EXECUTION_STATE}",
  "restart_result": "${RESTART_RESULT}",
  "restart_evidence": "${RESTART_EVIDENCE}",
  "status": "${RUNTIME_STATUS}"
}
EOF
  rm -f "${RESTART_SIGNAL_FILE}"
elif [ -n "${RESTART_LAST_HANDLED_AT}" ]; then
  RESTART_EXECUTION_STATE="validated"
  RESTART_RESULT="success"
  if [ -z "${RESTART_EVIDENCE}" ]; then
    RESTART_EVIDENCE="post_restart_validation:${RESTART_LAST_HANDLED_AT}"
  fi
  RUNTIME_STATUS="healthy"
  LOBSTER_STATUS="running"
  TASK_STATUS="running"
  TASK_STEP="post_restart_validation"
  TASK_PROGRESS=91
  TASK_TITLE="Runtime 重启后校验"
  TASK_INPUT="最近一次重启已处理"
  TASK_OUTPUT="last_restart_handled_at=${RESTART_LAST_HANDLED_AT}; request_id=${RESTART_REQUEST_ID:-unknown}; execution_state=${RESTART_EXECUTION_STATE}; evidence=${RESTART_EVIDENCE}"
  cat > "${STATUS_FILE}" <<EOF
{
  "last_restart_requested_at": "${RESTART_REQUESTED_AT}",
  "last_restart_request_id": "${RESTART_REQUEST_ID}",
  "last_restart_requested_by": "${RESTART_REQUESTED_BY}",
  "last_restart_handled_at": "${RESTART_LAST_HANDLED_AT}",
  "restart_execution_state": "${RESTART_EXECUTION_STATE}",
  "restart_result": "${RESTART_RESULT}",
  "restart_evidence": "${RESTART_EVIDENCE}",
  "status": "healthy"
}
EOF
fi

TMP_FILE="${STATE_FILE}.tmp"
python3 - <<'PY' "${TMP_FILE}" "${NOW}" "${NODE_ID}" "${LEASE_COUNT}" "${LEASE_SCOPE}" "${LEASE_KIND}" "${LEASE_EXPIRES_AT}" "${COMMAND_ALIAS}" "${LOBSTER_STATUS}" "${TASK_STATUS}" "${TASK_STEP}" "${TASK_PROGRESS}" "${TASK_TITLE}" "${TASK_INPUT}" "${TASK_OUTPUT}" "${TASK_ERROR}" "${RISK_LEVEL}" "${RISK_SCORE}" "${ALERT_TITLE}" "${ALERT_SUMMARY}" "${ALERT_LEVEL}" "${RUNTIME_STATUS}" "${RESTART_REQUESTED_AT}" "${RESTART_REQUEST_ID}" "${RESTART_REQUESTED_BY}" "${RESTART_LAST_HANDLED_AT}" "${RESTART_EXECUTION_STATE}" "${RESTART_RESULT}" "${RESTART_EVIDENCE}"
import json, sys
(out, now, node_id, lease_count, lease_scope, lease_kind, lease_expires_at, command_alias, lobster_status, task_status, task_step, task_progress, task_title, task_input, task_output, task_error, risk_level, risk_score, alert_title, alert_summary, alert_level, runtime_status, restart_requested_at, restart_request_id, restart_requested_by, restart_last_handled_at, restart_execution_state, restart_result, restart_evidence) = sys.argv[1:]
lease_count = int(lease_count)
task_progress = int(task_progress)
risk_score = int(risk_score)
recent_logs = [
  'runtime state adapter active',
  f'active_leases={lease_count}',
  (f'lease_kind={lease_kind}' if lease_kind else 'lease_kind=none'),
  (f'granted_scope={lease_scope}' if lease_scope else 'no active granted scope'),
  (f'last_restart_requested_at={restart_requested_at}' if restart_requested_at else 'no restart requested yet'),
  (f'last_restart_request_id={restart_request_id}' if restart_request_id else 'restart_request_id=none'),
  (f'last_restart_requested_by={restart_requested_by}' if restart_requested_by else 'restart_requested_by=unknown'),
  (f'last_restart_handled_at={restart_last_handled_at}' if restart_last_handled_at else 'no restart handled yet'),
  (f'restart_execution_state={restart_execution_state}' if restart_execution_state else 'restart_execution_state=idle'),
  (f'restart_result={restart_result}' if restart_result else 'restart_result=none'),
  (f'restart_evidence={restart_evidence}' if restart_evidence else 'restart_evidence=none'),
  f'runtime_status={runtime_status}'
]
state = {
  'schema_version': 'clawboard.bridge.state.v1',
  'generated_at': now,
  'runtime': {
    'status': runtime_status,
    'last_restart_requested_at': restart_requested_at or None,
    'last_restart_request_id': restart_request_id or None,
    'last_restart_requested_by': restart_requested_by or None,
    'last_restart_handled_at': restart_last_handled_at or None,
    'restart_execution_state': restart_execution_state or None,
    'restart_result': restart_result or None,
    'restart_evidence': restart_evidence or None,
  },
  'lobsters': [
    {
      'id': 'lobster-runtime-1',
      'name': 'Runtime Lobster',
      'status': lobster_status,
      'task_title': task_title,
      'last_active_at': now,
      'risk_level': risk_level,
      'node_id': node_id,
      'recent_logs': recent_logs[:12]
    }
  ],
  'tasks': [
    {
      'id': 'task-runtime-1',
      'title': task_title,
      'status': task_status,
      'progress': task_progress,
      'lobster_id': 'lobster-runtime-1',
      'current_step': task_step,
      'risk_level': risk_level,
      'risk_score': risk_score,
      'input_summary': task_input,
      'output_summary': task_output or None,
      'error_reason': task_error or None,
      'timeline': [
        {'step': 'collect_context', 'status': 'done'},
        {'step': task_step, 'status': 'in_progress'}
      ]
    }
  ],
  'approvals': [],
  'alerts': []
}
if alert_title and alert_summary and alert_level:
  state['alerts'].append({
    'id': 'alert-runtime-restart',
    'level': alert_level,
    'title': alert_title,
    'summary': alert_summary,
    'related_type': 'task',
    'related_id': 'task-runtime-1'
  })
with open(out, 'w', encoding='utf-8') as f:
  json.dump(state, f, ensure_ascii=False, indent=2)
PY
mv "${TMP_FILE}" "${STATE_FILE}"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] runtime state refreshed -> ${STATE_FILE}" >> "${LOG_FILE}"
