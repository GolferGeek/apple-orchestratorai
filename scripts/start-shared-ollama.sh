#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="${APPLE_AI_RUNTIME_ROOT:-/Users/golfergeek/projects/golfergeek/apple-ai-runtime}"
OLLAMA_APP="${RUNTIME_ROOT}/ollama/Ollama.app"
OLLAMA_BIN="${OLLAMA_APP}/Contents/Resources/ollama"
LOG_DIR="${RUNTIME_ROOT}/logs"
HOST="${OLLAMA_HOST:-127.0.0.1:11435}"
MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-2}"
KEEP_ALIVE="${OLLAMA_KEEP_ALIVE:--1}"
LABEL="com.golfergeek.apple-ai-runtime.ollama"
GUI_DOMAIN="gui/$(id -u)"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [[ ! -x "${OLLAMA_BIN}" ]]; then
  echo "Shared Ollama runtime not found at ${OLLAMA_BIN}" >&2
  echo "Install or copy Ollama.app into ${RUNTIME_ROOT}/ollama/Ollama.app." >&2
  exit 1
fi

mkdir -p "${LOG_DIR}"
mkdir -p "$(dirname "${PLIST}")"

if version_json="$(curl -fsS "http://${HOST}/api/version" 2>/dev/null)"; then
  echo "Ollama already running at ${HOST}: ${version_json}"
  exit 0
fi

stdout_log="${LOG_DIR}/ollama-${HOST//[:.]/-}.out.log"
stderr_log="${LOG_DIR}/ollama-${HOST//[:.]/-}.err.log"

echo "Starting shared Ollama runtime:"
echo "  binary: ${OLLAMA_BIN}"
echo "  host:   ${HOST}"
echo "  plist:  ${PLIST}"
echo "  stdout: ${stdout_log}"
echo "  stderr: ${stderr_log}"

cat >"${PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${OLLAMA_BIN}</string>
    <string>serve</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OLLAMA_HOST</key>
    <string>${HOST}</string>
    <key>OLLAMA_MAX_LOADED_MODELS</key>
    <string>${MAX_LOADED_MODELS}</string>
    <key>OLLAMA_KEEP_ALIVE</key>
    <string>${KEEP_ALIVE}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${stdout_log}</string>
  <key>StandardErrorPath</key>
  <string>${stderr_log}</string>
</dict>
</plist>
PLIST

if launchctl print "${GUI_DOMAIN}/${LABEL}" >/dev/null 2>&1; then
  launchctl bootout "${GUI_DOMAIN}/${LABEL}" >/dev/null 2>&1 || true
fi

launchctl bootstrap "${GUI_DOMAIN}" "${PLIST}"
launchctl kickstart -k "${GUI_DOMAIN}/${LABEL}"

for _ in {1..30}; do
  if version_json="$(curl -fsS "http://${HOST}/api/version" 2>/dev/null)"; then
    echo "ok: Ollama server ${HOST} ${version_json}"
    exit 0
  fi
  sleep 1
done

echo "Ollama did not become ready at ${HOST}. See ${stdout_log} and ${stderr_log}" >&2
exit 1
