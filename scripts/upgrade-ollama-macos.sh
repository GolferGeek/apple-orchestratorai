#!/usr/bin/env bash
set -euo pipefail

OLLAMA_VERSION="${OLLAMA_VERSION:-v0.31.1}"
ASSET_URL="${ASSET_URL:-https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/Ollama-darwin.zip}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCOPE="${INSTALL_SCOPE:-project}"
APP_PATH="${APP_PATH:-${ROOT_DIR}/.runtime/ollama/Ollama.app}"
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11435}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This upgrade script is macOS-only." >&2
  exit 1
fi

if [[ "${INSTALL_SCOPE}" == "app" ]]; then
  APP_PATH="/Applications/Ollama.app"
  APP_PARENT="$(dirname "${APP_PATH}")"
  if [[ ! -w "${APP_PARENT}" ]]; then
    echo "${APP_PARENT} is not writable by the current user." >&2
    echo "Run the official Ollama updater, or rerun this script with permissions that can replace ${APP_PATH}." >&2
    exit 1
  fi
fi

before="not installed"
if command -v ollama >/dev/null 2>&1; then
  before="$(ollama --version 2>/dev/null || true)"
fi

echo "Current: ${before}"
echo "Downloading ${ASSET_URL}"
curl -fL "${ASSET_URL}" -o "${TMP_DIR}/Ollama-darwin.zip"

echo "Stopping running Ollama processes if any"
osascript -e 'tell application "Ollama" to quit' >/dev/null 2>&1 || true
pkill -x ollama >/dev/null 2>&1 || true
sleep 2

echo "Unpacking Ollama"
ditto -x -k "${TMP_DIR}/Ollama-darwin.zip" "${TMP_DIR}/unpacked"

if [[ ! -d "${TMP_DIR}/unpacked/Ollama.app" ]]; then
  echo "Downloaded archive did not contain Ollama.app" >&2
  exit 1
fi

mkdir -p "$(dirname "${APP_PATH}")"

if [[ -d "${APP_PATH}" ]]; then
  backup="${APP_PATH}.backup.$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing app to ${backup}"
  mv "${APP_PATH}" "${backup}"
fi

echo "Installing ${APP_PATH}"
mv "${TMP_DIR}/unpacked/Ollama.app" "${APP_PATH}"

if [[ "${INSTALL_SCOPE}" == "project" ]]; then
  cat > "${ROOT_DIR}/.runtime/ollama-env.sh" <<EOF
#!/usr/bin/env bash
export APPLE_ORCHESTRATOR_OLLAMA_BIN="${APP_PATH}/Contents/Resources/ollama"
export OLLAMA_HOST="${OLLAMA_HOST}"
export PATH="${APP_PATH}/Contents/Resources:\$PATH"
EOF
  chmod 700 "${ROOT_DIR}/.runtime/ollama-env.sh"
  echo "Starting project-local Ollama on ${OLLAMA_HOST}"
  "${ROOT_DIR}/scripts/start-ollama-mlx.sh"
else
  echo "Starting Ollama"
  open -a Ollama
  sleep 3
fi

echo "Updated: $("${APP_PATH}/Contents/Resources/ollama" --version)"
