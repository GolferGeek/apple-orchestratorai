#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${ROOT_DIR}/mac-app/AppleAssistant"
EXECUTABLE="${PACKAGE_DIR}/.build/arm64-apple-macosx/debug/AppleAssistant"
APP_DIR="${PACKAGE_DIR}/.build/AppleAssistant.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

"${ROOT_DIR}/scripts/build-apple-assistant.sh" >/dev/null

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

cp "${EXECUTABLE}" "${MACOS_DIR}/AppleAssistant"
cp "${PACKAGE_DIR}/Sources/AppleAssistant/Info.plist" "${CONTENTS_DIR}/Info.plist"
chmod +x "${MACOS_DIR}/AppleAssistant"

echo "${APP_DIR}"
