#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.runtime/hermes-env.sh"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

API_SERVER_HOST="${API_SERVER_HOST:-127.0.0.1}"
API_SERVER_PORT="${API_SERVER_PORT:-8642}"
API_SERVER_KEY="${API_SERVER_KEY:-apple-orchestratorai-local-dev}"
BASE_URL="http://${API_SERVER_HOST}:${API_SERVER_PORT}"

echo "Probing Hermes API at ${BASE_URL}"

curl -fsS "${BASE_URL}/health"
echo

curl -fsS \
  -H "Authorization: Bearer ${API_SERVER_KEY}" \
  "${BASE_URL}/v1/capabilities"
echo

curl -fsS \
  -H "Authorization: Bearer ${API_SERVER_KEY}" \
  "${BASE_URL}/v1/models"
echo
