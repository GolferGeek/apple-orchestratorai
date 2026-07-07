#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${ROOT_DIR}/mac-app/AppleOrchestratorAI"
EXECUTABLE="${PACKAGE_DIR}/.build/arm64-apple-macosx/debug/AppleOrchestratorAI"
APP_DIR="${PACKAGE_DIR}/.build/AppleOrchestratorAI.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

"${ROOT_DIR}/scripts/build-mac-app.sh" >/dev/null

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

cp "${EXECUTABLE}" "${MACOS_DIR}/AppleOrchestratorAI"
cp "${PACKAGE_DIR}/Sources/AppleOrchestratorAI/Info.plist" "${CONTENTS_DIR}/Info.plist"
chmod +x "${MACOS_DIR}/AppleOrchestratorAI"

echo "${APP_DIR}"
