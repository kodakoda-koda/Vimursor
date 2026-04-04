#!/usr/bin/env bash
# scripts/build-dmg.sh — Create a dmg installer from Vimursor.app
# Usage: bash scripts/build-dmg.sh
# Prerequisite: Run scripts/build-app.sh first

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Vimursor"
APP_BUNDLE="${REPO_ROOT}/${APP_NAME}.app"
DMG_PATH="${REPO_ROOT}/${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"

if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "ERROR: ${APP_BUNDLE} not found. Run scripts/build-app.sh first." >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "==> Preparing dmg contents..."
cp -r "${APP_BUNDLE}" "${TMP_DIR}/"
ln -s /Applications "${TMP_DIR}/Applications"

echo "==> Creating ${APP_NAME}.dmg..."
rm -f "${DMG_PATH}"
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${TMP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

echo "==> Done: ${DMG_PATH}"
echo "    Open with: open ${DMG_PATH}"
