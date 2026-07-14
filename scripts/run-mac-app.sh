#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$("${ROOT_DIR}/scripts/package-mac-app.sh")"

APPLE_ORCHESTRATORAI_REPO_ROOT="${ROOT_DIR}" open -n "${APP_PATH}"
