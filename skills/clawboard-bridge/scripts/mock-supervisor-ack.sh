#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/runtime"
MODE="${1:-supervised}"
STATE="${2:-acknowledged}"
RESULT="${3:-success}"

case "${MODE}" in
  supervised)
    ACK_FILE="${RUNTIME_DIR}/restart-ack.supervised.json"
    TARGET="host_supervisor"
    ;;
  container)
    ACK_FILE="${RUNTIME_DIR}/restart-ack.container.json"
    TARGET="container_runtime"
    ;;
  *)
    echo "用法: bash scripts/mock-supervisor-ack.sh [supervised|container] [acknowledged|completed|failed] [success|error]" >&2
    exit 1
    ;;
esac

if [ ! -f "${ACK_FILE}" ]; then
  echo "[ERR] ack 文件不存在: ${ACK_FILE}" >&2
  echo "请先让 bridge 在对应 profile 下发起一次 restart 请求。" >&2
  exit 1
fi

UPDATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TMP_FILE="${ACK_FILE}.tmp"
python3 - <<'PY' "${ACK_FILE}" "${TMP_FILE}" "${STATE}" "${RESULT}" "${UPDATED_AT}" "${TARGET}"
import json, pathlib, sys
ack_path, tmp_path, state, result, updated_at, target = sys.argv[1:]
p = pathlib.Path(ack_path)
raw = json.loads(p.read_text())
raw['status'] = state
raw['target'] = raw.get('target') or target
raw['updated_at'] = updated_at
if state == 'acknowledged':
    raw['result'] = None
    raw['evidence'] = f"mock_supervisor_acknowledged:{raw.get('target') or target}"
elif state == 'completed':
    raw['result'] = result or 'success'
    raw['evidence'] = f"mock_supervisor_completed:{raw.get('target') or target}:result={raw['result']}"
elif state == 'failed':
    raw['result'] = result or 'error'
    raw['evidence'] = f"mock_supervisor_failed:{raw.get('target') or target}:result={raw['result']}"
else:
    raw['result'] = raw.get('result')
    raw['evidence'] = f"mock_supervisor_state:{state}:{raw.get('target') or target}"
pathlib.Path(tmp_path).write_text(json.dumps(raw, ensure_ascii=False, indent=2) + '\n')
PY
mv "${TMP_FILE}" "${ACK_FILE}"

echo "[OK] 已更新 ack 文件: ${ACK_FILE}"
echo "mode: ${MODE}"
echo "status: ${STATE}"
echo "result: ${RESULT}"
echo "updated_at: ${UPDATED_AT}"
