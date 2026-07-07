#!/usr/bin/env bash
set -euo pipefail

TIER="${1:-core}"

case "${TIER}" in
  smoke)
    models=(
      "gemma4:e2b-mlx"
      "gemma4:e4b-mlx"
    )
    ;;
  core)
    models=(
      "gemma4:e2b-mlx"
      "gemma4:e4b-mlx"
      "gemma4:12b-mlx"
      "qwen3.6:27b-mlx"
    )
    ;;
  workstation)
    models=(
      "gemma4:e2b-mlx"
      "gemma4:e4b-mlx"
      "gemma4:12b-mlx"
      "gemma4:26b-mlx"
      "qwen3.6:27b-mlx"
    )
    ;;
  full)
    models=(
      "gemma4:e2b-mlx"
      "gemma4:e4b-mlx"
      "gemma4:12b-mlx"
      "gemma4:26b-mlx"
      "gemma4:31b-mlx"
      "qwen3.6:27b-mlx"
      "qwen3.6:35b-mlx"
    )
    ;;
  *)
    echo "Usage: $0 [smoke|core|workstation|full]" >&2
    exit 1
    ;;
esac

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama is not installed or not on PATH" >&2
  exit 1
fi

for model in "${models[@]}"; do
  echo "Pulling ${model}"
  ollama pull "${model}"
done

echo
echo "Installed MLX model tags:"
ollama list | awk 'NR == 1 || $1 ~ /-mlx$/ { print }'
