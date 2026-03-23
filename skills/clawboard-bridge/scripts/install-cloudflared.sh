#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${ROOT_DIR}/runtime/bin"
TARGET_BIN="${BIN_DIR}/cloudflared"
ARCH="$(uname -m)"

case "${ARCH}" in
  x86_64|amd64) ASSET="cloudflared-linux-amd64" ;;
  aarch64|arm64) ASSET="cloudflared-linux-arm64" ;;
  *) echo "[ERROR] 不支持的架构: ${ARCH}"; exit 1 ;;
esac

URL="https://github.com/cloudflare/cloudflared/releases/latest/download/${ASSET}"
TMP_FILE="$(mktemp)"
cleanup() {
  rm -f "${TMP_FILE}"
}
trap cleanup EXIT

mkdir -p "${BIN_DIR}"

echo "==> 下载 cloudflared"
echo "URL: ${URL}"

if command -v curl >/dev/null 2>&1; then
  curl -L --fail --connect-timeout 20 "${URL}" -o "${TMP_FILE}"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "${TMP_FILE}" "${URL}"
else
  echo "[ERROR] 需要 curl 或 wget 才能下载 cloudflared"
  exit 1
fi

install -m 755 "${TMP_FILE}" "${TARGET_BIN}"

echo "[OK] cloudflared 已安装到: ${TARGET_BIN}"
"${TARGET_BIN}" --version
