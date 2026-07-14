#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

status() {
  printf '%s\n' "$1"
}

check_command() {
  local name="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    status "ok: $name found at $(command -v "$command_name")"
  else
    status "missing: $name ($command_name)"
  fi
}

check_command_or_path() {
  local name="$1"
  local command_name="$2"
  local fallback_path="$3"

  if command -v "$command_name" >/dev/null 2>&1; then
    status "ok: $name found at $(command -v "$command_name")"
  elif [[ -x "$fallback_path" ]]; then
    status "ok: $name found at $fallback_path"
  else
    status "missing: $name ($command_name)"
  fi
}

status "Apple Orchestrator AI Mac readiness check"
status "root: $ROOT_DIR"
status ""

status "System"
status "macOS: $(sw_vers -productVersion 2>/dev/null || echo unknown)"
status "architecture: $(uname -m)"
status "memory: $(sysctl -n hw.memsize 2>/dev/null | awk '{ printf "%.1f GB", $1 / 1024 / 1024 / 1024 }' || echo unknown)"
status ""

status "Developer tools"
check_command "Xcode build tool" "xcodebuild"
check_command "Swift" "swift"
check_command "codesign" "codesign"
check_command "hdiutil" "hdiutil"
status ""

status "Runtime tools"
check_command "Pi" "pi"
check_command "Ollama" "ollama"
status ""

status "Ollama endpoints"
for host in "127.0.0.1:11435" "127.0.0.1:11434"; do
  if version_json="$(curl -fsS "http://${host}/api/version" 2>/dev/null)"; then
    status "ok: Ollama server ${host} ${version_json}"
  else
    status "offline: Ollama server ${host}"
  fi
done
status ""

if command -v ollama >/dev/null 2>&1; then
  status "Ollama models"
  OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11435}" ollama list || true
  status ""
fi

status "Workflow agent"
if [[ -s "$ROOT_DIR/workflows/legal/document-onboarding.workflow-agent.md" ]]; then
  status "ok: document-onboarding.workflow-agent.md found"
else
  status "missing: document-onboarding.workflow-agent.md"
fi

status ""
status "done"
