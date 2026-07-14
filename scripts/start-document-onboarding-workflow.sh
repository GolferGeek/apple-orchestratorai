#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-document-onboarding-app-$(date -u +%Y%m%dT%H%M%SZ)}"
MODEL="${MODEL:-qwen3.6:27b-mlx}"
LOG_DIR="${STATE_DIR}/logs"
PID_FILE="${STATE_DIR}/runs/${RUN_ID}.pid"
LOG_FILE="${LOG_DIR}/${RUN_ID}.log"

mkdir -p "${LOG_DIR}" "${STATE_DIR}/runs"

if [[ -f "${PID_FILE}" ]]; then
  existing_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
    echo "run already active: ${RUN_ID} (pid ${existing_pid})"
    exit 0
  fi
fi

RUN_ID="${RUN_ID}" \
MODEL="${MODEL}" \
APPLE_ORCHESTRATOR_STATE_DIR="${STATE_DIR}" \
/usr/bin/nohup /bin/bash "${ROOT_DIR}/scripts/smoke-document-onboarding-full.sh" \
  > "${LOG_FILE}" 2>&1 < /dev/null &
pid=$!
echo "${pid}" > "${PID_FILE}"

echo "run-id: ${RUN_ID}"
echo "pid: ${pid}"
echo "log-file: ${LOG_FILE}"
