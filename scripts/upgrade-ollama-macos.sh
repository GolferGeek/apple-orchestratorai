#!/usr/bin/env bash
set -euo pipefail

OLLAMA_VERSION="${OLLAMA_VERSION:-v0.31.1}"
ASSET_URL="${ASSET_URL:-https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/Ollama-darwin.zip}"
APP_PATH="${APP_PATH:-/Applications/Ollama.app}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This upgrade script is macOS-only." >&2
  exit 1
fi

APP_PARENT="$(dirname "${APP_PATH}")"

if [[ ! -w "${APP_PARENT}" ]]; then
  echo "${APP_PARENT} is not writable by the current user." >&2
  echo "Run the official Ollama updater, or rerun this script with permissions that can replace ${APP_PATH}." >&2
  exit 1
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

if [[ -d "${APP_PATH}" ]]; then
  backup="${APP_PATH}.backup.$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing app to ${backup}"
  mv "${APP_PATH}" "${backup}"
fi

echo "Installing ${APP_PATH}"
mv "${TMP_DIR}/unpacked/Ollama.app" "${APP_PATH}"

echo "Starting Ollama"
open -a Ollama
sleep 3

echo "Updated: $(ollama --version)"
