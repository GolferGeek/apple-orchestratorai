#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLLAMA_BIN="${APPLE_ORCHESTRATOR_OLLAMA_BIN:-${ROOT_DIR}/.runtime/ollama/Ollama.app/Contents/Resources/ollama}"
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11435}"
PID_FILE="${ROOT_DIR}/.runtime/ollama/ollama.pid"
LOG_FILE="${ROOT_DIR}/.runtime/logs/ollama-0.31.1-11435.log"
PLIST_FILE="${ROOT_DIR}/.runtime/ollama/io.orchestratorai.ollama-mlx.plist"
LAUNCH_LABEL="io.orchestratorai.ollama-mlx"
LAUNCH_DOMAIN="gui/$(id -u)"

if [[ ! -x "${OLLAMA_BIN}" ]]; then
  echo "Project-local Ollama binary not found at ${OLLAMA_BIN}" >&2
  echo "Run scripts/upgrade-ollama-macos.sh first." >&2
  exit 1
fi

mkdir -p "$(dirname "${PID_FILE}")" "$(dirname "${LOG_FILE}")"

launchctl bootout "${LAUNCH_DOMAIN}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

cat > "${PLIST_FILE}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCH_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${OLLAMA_BIN}</string>
    <string>serve</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OLLAMA_HOST</key>
    <string>${OLLAMA_HOST}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>
</dict>
</plist>
PLIST

launchctl bootstrap "${LAUNCH_DOMAIN}" "${PLIST_FILE}"
launchctl kickstart -k "${LAUNCH_DOMAIN}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

pgrep -f "${OLLAMA_BIN} serve" | head -n 1 > "${PID_FILE}" || true
sleep 3

OLLAMA_HOST="${OLLAMA_HOST}" "${OLLAMA_BIN}" --version
curl --max-time 5 -fsS "http://${OLLAMA_HOST}/api/version"
echo
