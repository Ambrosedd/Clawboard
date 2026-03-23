#!/usr/bin/env bash
set -euo pipefail

INSTALL_REPO_OWNER="Ambrosedd"
INSTALL_REPO_NAME="clawboard-install"
INSTALL_REPO_REF="${CLAWBOARD_INSTALL_REPO_REF:-main}"
BUNDLE_URL="https://raw.githubusercontent.com/${INSTALL_REPO_OWNER}/${INSTALL_REPO_NAME}/${INSTALL_REPO_REF}/dist/clawboard-bridge-bundle.tar.gz"
WORK_DIR="$(mktemp -d)"
ARCHIVE_PATH="${WORK_DIR}/clawboard-bridge-bundle.tar.gz"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
    return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
    return 0
  fi
  echo "[ERROR] 需要 curl 或 wget 才能下载安装 Clawboard skill。"
  exit 1
}

detect_public_host() {
  if [ -n "${PUBLIC_HOST:-}" ]; then
    printf '%s\n' "${PUBLIC_HOST}"
    return 0
  fi

  local ip=""
  if command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  if [ -z "${ip}" ] && command -v ip >/dev/null 2>&1; then
    ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
  fi
  if [ -z "${ip}" ] && command -v python3 >/dev/null 2>&1; then
    ip="$(python3 - <<'PY'
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(('1.1.1.1', 80))
    print(s.getsockname()[0])
finally:
    s.close()
PY
)"
  fi

  if [ -z "${ip}" ]; then
    ip="127.0.0.1"
  fi
  printf '%s\n' "${ip}"
}

echo "==> 下载 Clawboard Bridge skill bundle"
fetch "${BUNDLE_URL}" "${ARCHIVE_PATH}"

tar -xzf "${ARCHIVE_PATH}" -C "${WORK_DIR}"
BUNDLE_DIR="${WORK_DIR}/clawboard-bridge-bundle"
TARGET_ROOT="${CLAWBOARD_INSTALL_ROOT:-$HOME/.clawboard}"
TARGET_DIR="${TARGET_ROOT}/skills/clawboard-bridge"

if [ ! -d "${BUNDLE_DIR}/skill" ] || [ ! -d "${BUNDLE_DIR}/runtime/connector" ]; then
  echo "[ERROR] 下载成功，但 bundle 结构不完整。"
  exit 1
fi

mkdir -p "${TARGET_ROOT}/skills"
rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"
cp -R "${BUNDLE_DIR}/skill/." "${TARGET_DIR}/"
mkdir -p "${TARGET_DIR}/runtime"
cp -R "${BUNDLE_DIR}/runtime/connector" "${TARGET_DIR}/runtime/connector"
mkdir -p "${TARGET_DIR}/config" "${TARGET_DIR}/logs" "${TARGET_DIR}/run"

if [ ! -f "${TARGET_DIR}/config/bridge.env" ]; then
  cp "${TARGET_DIR}/skill.env.example" "${TARGET_DIR}/config/bridge.env"
fi

CONFIG_FILE="${TARGET_DIR}/config/bridge.env"
BRIDGE_PORT="${CLAWBOARD_BRIDGE_PORT:-8787}"
PAIR_CODE="${CLAWBOARD_PAIR_CODE:-LX-472911}"
BRIDGE_HOST="$(detect_public_host)"

sed -i "s/^PORT=.*/PORT=${BRIDGE_PORT}/" "${CONFIG_FILE}"
sed -i "s/^PAIR_CODE=.*/PAIR_CODE=${PAIR_CODE}/" "${CONFIG_FILE}"
sed -i "s/^PUBLIC_HOST=.*/PUBLIC_HOST=${BRIDGE_HOST}/" "${CONFIG_FILE}"

PAIRING_LINK="clawboard://pair?code=${PAIR_CODE}&url=http://${BRIDGE_HOST}:${BRIDGE_PORT}"

echo
echo "[OK] Bootstrap 安装完成"
echo "接下来建议："
echo "  cd ${TARGET_DIR}"
echo "  bash scripts/start-bridge.sh"
echo "  bash scripts/show-connection.sh"
echo
echo "默认会优先使用可访问地址生成连接串："
echo "  ${PAIRING_LINK}"
