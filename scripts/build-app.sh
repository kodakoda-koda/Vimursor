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

echo "==> Building universal release binary..."
cd "${REPO_ROOT}"
swift build -c release --arch arm64 --arch x86_64
BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BINARY_SRC="${BIN_PATH}/${APP_NAME}"

echo "==> Assembling ${APP_NAME}.app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BINARY_SRC}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "${INFO_PLIST_SRC}" "${CONTENTS}/Info.plist"

echo "==> Copying resources..."
RESOURCES_SRC="${REPO_ROOT}/Resources"
if [ -f "${RESOURCES_SRC}/AppIcon.icns" ]; then
    cp "${RESOURCES_SRC}/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
elif [ -z "${ALLOW_MISSING_RESOURCES:-}" ]; then
    echo "  ERROR: AppIcon.icns not found (run: swift scripts/generate-icon.swift)"
    exit 1
else
    echo "  WARNING: AppIcon.icns not found, skipping (run: swift scripts/generate-icon.swift)"
fi
if [ -f "${RESOURCES_SRC}/MenuBarIcon.png" ]; then
    cp "${RESOURCES_SRC}/MenuBarIcon.png" "${RESOURCES_DIR}/MenuBarIcon.png"
elif [ -z "${ALLOW_MISSING_RESOURCES:-}" ]; then
    echo "  ERROR: MenuBarIcon.png not found (run: swift scripts/generate-icon.swift)"
    exit 1
else
    echo "  WARNING: MenuBarIcon.png not found, skipping (run: swift scripts/generate-icon.swift)"
fi
if [ -f "${RESOURCES_SRC}/MenuBarIcon@2x.png" ]; then
    cp "${RESOURCES_SRC}/MenuBarIcon@2x.png" "${RESOURCES_DIR}/MenuBarIcon@2x.png"
elif [ -z "${ALLOW_MISSING_RESOURCES:-}" ]; then
    echo "  ERROR: MenuBarIcon@2x.png not found (run: swift scripts/generate-icon.swift)"
    exit 1
else
    echo "  WARNING: MenuBarIcon@2x.png not found, skipping (run: swift scripts/generate-icon.swift)"
fi

# Inject version from git tag (e.g., v1.0.0 → 1.0.0)
VERSION="${VIMURSOR_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.9.0")}"
VERSION=$(echo "${VERSION}" | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' || echo "0.9.0")
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${CONTENTS}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${CONTENTS}/Info.plist"

echo "==> Signing bundle (ad-hoc)..."
xattr -cr "${APP_BUNDLE}"
codesign -s - -f --deep \
  --entitlements "${REPO_ROOT}/Sources/Vimursor/Vimursor.entitlements" \
  "${APP_BUNDLE}"

echo "==> Validating bundle..."
plutil -lint "${CONTENTS}/Info.plist"

echo "==> Done: ${APP_BUNDLE}"
echo "    Launch with: open ${APP_BUNDLE}"
