#!/usr/bin/env bash
set -euo pipefail

MIN_OLLAMA_VERSION="${MIN_OLLAMA_VERSION:-0.31.1}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama is not installed or not on PATH" >&2
  exit 1
fi

current="$(ollama --version | awk '{print $NF}')"

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
ollama list | awk 'NR == 1 || $1 ~ /-mlx$/ { print }'
