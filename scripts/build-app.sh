#!/usr/bin/env bash
# scripts/build-app.sh — Package Vimursor into a macOS .app bundle
# Usage: bash scripts/build-app.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Vimursor"
APP_BUNDLE="${REPO_ROOT}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"
INFO_PLIST_SRC="${REPO_ROOT}/Sources/Vimursor/Info.plist"
BINARY_SRC="${REPO_ROOT}/.build/release/${APP_NAME}"

echo "==> Building release binary..."
cd "${REPO_ROOT}"
swift build -c release

echo "==> Assembling ${APP_NAME}.app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BINARY_SRC}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "${INFO_PLIST_SRC}" "${CONTENTS}/Info.plist"

echo "==> Validating bundle..."
plutil -lint "${CONTENTS}/Info.plist"

echo "==> Done: ${APP_BUNDLE}"
echo "    Launch with: open ${APP_BUNDLE}"
