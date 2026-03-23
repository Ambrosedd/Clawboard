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

echo
echo "[OK] Bootstrap 安装完成"
echo "接下来建议："
echo "  cd ${TARGET_DIR}"
echo "  bash scripts/start-bridge.sh"
echo "  bash scripts/show-connection.sh"
