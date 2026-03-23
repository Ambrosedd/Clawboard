#!/usr/bin/env bash
set -euo pipefail

TARGET_REPO_DIR="${1:-}"
if [ -z "${TARGET_REPO_DIR}" ]; then
  echo "用法: bash install/publish-to-clawboard-install.sh /path/to/clawboard-install"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO_DIR="$(cd "${TARGET_REPO_DIR}" && pwd)"
DIST_DIR="${TARGET_REPO_DIR}/dist"

mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR}/clawboard-bridge-bundle"
mkdir -p "${DIST_DIR}/clawboard-bridge-bundle"

cp -R "${REPO_ROOT}/skills/clawboard-bridge" "${DIST_DIR}/clawboard-bridge-bundle/skill"
mkdir -p "${DIST_DIR}/clawboard-bridge-bundle/runtime"
cp -R "${REPO_ROOT}/connector" "${DIST_DIR}/clawboard-bridge-bundle/runtime/connector"
cp "${REPO_ROOT}/install/bootstrap-clawboard-bridge.sh" "${TARGET_REPO_DIR}/bootstrap-clawboard-bridge.sh"

rm -f "${DIST_DIR}/clawboard-bridge-bundle.tar.gz"
tar -czf "${DIST_DIR}/clawboard-bridge-bundle.tar.gz" -C "${DIST_DIR}" clawboard-bridge-bundle

cat > "${TARGET_REPO_DIR}/README.md" <<'EOF'
# clawboard-install

公开 installer 仓库，用于让用户/龙虾直接下载并安装 Clawboard Bridge skill。

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/Ambrosedd/clawboard-install/main/bootstrap-clawboard-bridge.sh | bash
```

## 直接下载脚本

- bootstrap:
  - https://raw.githubusercontent.com/Ambrosedd/clawboard-install/main/bootstrap-clawboard-bridge.sh
- bundle:
  - https://raw.githubusercontent.com/Ambrosedd/clawboard-install/main/dist/clawboard-bridge-bundle.tar.gz
EOF

echo "[OK] 已生成发布内容到: ${TARGET_REPO_DIR}"
echo "下一步："
echo "  cd ${TARGET_REPO_DIR}"
echo "  git status"
echo "  git add . && git commit -m 'publish clawboard installer bundle' && git push"
