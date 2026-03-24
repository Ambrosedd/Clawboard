#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/runtime"

show_ack() {
  local label="$1"
  local file="$2"
  echo "== ${label} =="
  if [ ! -f "${file}" ]; then
    echo "(missing) ${file}"
    echo
    return
  fi
  python3 - <<'PY' "${file}"
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
try:
    data = json.loads(p.read_text())
except Exception as e:
    print(f"invalid json: {e}")
    raise SystemExit(0)
for key in ['status', 'target', 'request_id', 'requested_at', 'requested_by', 'result', 'evidence', 'updated_at']:
    print(f"{key}: {data.get(key)}")
PY
  echo
}

show_ack "container" "${RUNTIME_DIR}/restart-ack.container.json"
show_ack "supervised" "${RUNTIME_DIR}/restart-ack.supervised.json"
