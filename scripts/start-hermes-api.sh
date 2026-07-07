#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.runtime/hermes-env.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Hermes is not bootstrapped yet. Run scripts/bootstrap-hermes.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

exec hermes gateway
