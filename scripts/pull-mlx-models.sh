#!/usr/bin/env bash
set -euo pipefail

TIER="${1:-core}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED_OLLAMA_BIN="${APPLE_AI_RUNTIME_ROOT:-/Users/golfergeek/projects/golfergeek/apple-ai-runtime}/ollama/Ollama.app/Contents/Resources/ollama"
PROJECT_OLLAMA_BIN="${ROOT_DIR}/.runtime/ollama/Ollama.app/Contents/Resources/ollama"

if [[ -x "${SHARED_OLLAMA_BIN}" ]]; then
  OLLAMA_BIN="${APPLE_ORCHESTRATOR_OLLAMA_BIN:-${SHARED_OLLAMA_BIN}}"
  export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11435}"
elif [[ -x "${PROJECT_OLLAMA_BIN}" ]]; then
  OLLAMA_BIN="${APPLE_ORCHESTRATOR_OLLAMA_BIN:-${PROJECT_OLLAMA_BIN}}"
  export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11435}"
else
  OLLAMA_BIN="${APPLE_ORCHESTRATOR_OLLAMA_BIN:-ollama}"
fi

case "${TIER}" in
  smoke)
    models=(
      "gemma4:e2b-mlx"
      "gemma4:e4b-mlx"
    )
    ;;
  core)
    models=(
      "qwen3.6:35b-a3b-nvfp4"
      "qwen3.6:35b-a3b-coding-nvfp4"
      "gemma4:e2b-mlx"
      "gemma4:e4b-mlx"
    )
    ;;
  workstation)
    models=(
      "qwen3.6:35b-a3b-nvfp4"
      "qwen3.6:35b-a3b-coding-nvfp4"
      "gemma4:e2b-mlx"
      "gemma4:e4b-mlx"
      "deepseek-r1:70b"
    )
    ;;
  full)
    models=(
      "qwen3.6:35b-a3b-nvfp4"
      "qwen3.6:35b-a3b-coding-nvfp4"
      "gemma4:e2b-mlx"
      "gemma4:e4b-mlx"
      "deepseek-r1:70b"
      "gpt-oss:20b"
    )
    ;;
  *)
    echo "Usage: $0 [smoke|core|workstation|full]" >&2
    exit 1
    ;;
esac

if ! command -v "${OLLAMA_BIN}" >/dev/null 2>&1; then
  echo "ollama is not installed or not on PATH" >&2
  exit 1
fi

for model in "${models[@]}"; do
  echo "Pulling ${model}"
  "${OLLAMA_BIN}" pull "${model}"
done

echo
echo "Installed Apple-optimized model tags:"
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11435}" "${OLLAMA_BIN}" list | awk 'NR == 1 || $1 ~ /^(qwen3[.]6:35b-a3b(-coding)?-nvfp4|gemma4:e[24]b-mlx)$/ { print }'
