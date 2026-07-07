#!/usr/bin/env bash
set -euo pipefail

MIN_OLLAMA_VERSION="${MIN_OLLAMA_VERSION:-0.31.1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_OLLAMA_BIN="${ROOT_DIR}/.runtime/ollama/Ollama.app/Contents/Resources/ollama"

if [[ -x "${PROJECT_OLLAMA_BIN}" ]]; then
  OLLAMA_BIN="${APPLE_ORCHESTRATOR_OLLAMA_BIN:-${PROJECT_OLLAMA_BIN}}"
  export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11435}"
else
  OLLAMA_BIN="${APPLE_ORCHESTRATOR_OLLAMA_BIN:-ollama}"
fi

if ! command -v "${OLLAMA_BIN}" >/dev/null 2>&1; then
  echo "ollama is not installed or not on PATH" >&2
  exit 1
fi

current="$("${OLLAMA_BIN}" --version 2>&1 | sed -nE 's/.*version (is )?([0-9]+([.][0-9]+)+).*/\2/p' | tail -n 1)"

if [[ -z "${current}" ]]; then
  echo "Could not determine Ollama version from ${OLLAMA_BIN}" >&2
  exit 1
fi

python3 - "$current" "$MIN_OLLAMA_VERSION" <<'PY'
import sys

def parse_version(value):
    return tuple(int(part) for part in value.split("."))

current = parse_version(sys.argv[1])
minimum = parse_version(sys.argv[2])
if current < minimum:
    print(f"Ollama {sys.argv[1]} is below required MLX baseline {sys.argv[2]}")
    sys.exit(1)
print(f"Ollama {sys.argv[1]} satisfies MLX baseline {sys.argv[2]}")
PY

echo
echo "Installed MLX model tags:"
"${OLLAMA_BIN}" list | awk 'NR == 1 || $1 ~ /-mlx$/ { print }'
