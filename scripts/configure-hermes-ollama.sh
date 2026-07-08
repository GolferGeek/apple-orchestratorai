#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.runtime/hermes-env.sh"
MODEL="${1:-qwen3.6:35b-a3b-nvfp4}"
BASE_URL="${OLLAMA_OPENAI_BASE_URL:-http://127.0.0.1:11435/v1}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Hermes is not bootstrapped yet. Run scripts/bootstrap-hermes.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

hermes config set model.provider custom
hermes config set model.default "${MODEL}"
hermes config set model.base_url "${BASE_URL}"

echo "Hermes local Ollama route configured."
echo "model.provider: custom"
echo "model.default:  ${MODEL}"
echo "model.base_url: ${BASE_URL}"
