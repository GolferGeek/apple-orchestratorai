#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.runtime/pi-env.sh"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

PI_BIN="${PI_BIN:-${ROOT_DIR}/.runtime/pi/packages/coding-agent/dist/cli.js}"
PI_NODE_BIN="${PI_NODE_BIN:-$(command -v node || true)}"

if [[ ! -f "${PI_BIN}" ]]; then
  echo "Pi is not built yet. Run scripts/bootstrap-pi.sh first." >&2
  exit 1
fi

if [[ -z "${PI_NODE_BIN}" || ! -x "${PI_NODE_BIN}" ]]; then
  echo "node is required but was not found on PATH" >&2
  exit 1
fi

echo "Probing Pi CLI at ${PI_BIN}"
"${PI_NODE_BIN}" "${PI_BIN}" --version
"${PI_NODE_BIN}" "${PI_BIN}" --help | sed -n '1,40p'

echo
echo "Probing Pi RPC startup"
(
  printf '{"id":"probe-1","type":"get_state"}\n'
  sleep 1
) | "${PI_NODE_BIN}" "${PI_BIN}" --mode rpc --provider ollama --model qwen3.6:35b-mlx --api-key ollama --no-session --no-tools --no-extensions --no-skills --no-prompt-templates --no-context-files | sed -n '1,8p'

echo
echo "Probing Pi RPC event wrapper"
python3 "${ROOT_DIR}/scripts/smoke-pi-rpc-events.py" \
  --run-id "run-pi-probe-$(date -u +%Y%m%dT%H%M%SZ)" \
  --workflow-id "runtime.pi-probe" \
  --stage-id "runtime" \
  --work-unit-id "pi.rpc-probe" \
  --skill-id "runtime.pi-rpc-probe" \
  --timeout-seconds 20
