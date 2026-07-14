#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
RUN_ID="${2:-}"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
PID_FILE="${STATE_DIR}/runs/${RUN_ID}.pid"

if [[ ! "${ACTION}" =~ ^(pause|resume|stop)$ ]] || [[ -z "${RUN_ID}" ]]; then
  echo "usage: control-workflow-run.sh pause|resume|stop RUN_ID" >&2
  exit 64
fi

if [[ ! -f "${PID_FILE}" ]]; then
  echo "No active local process is recorded for ${RUN_ID}." >&2
  exit 1
fi

ROOT_PID="$(tr -d '[:space:]' < "${PID_FILE}")"
if [[ ! "${ROOT_PID}" =~ ^[0-9]+$ ]] || ! kill -0 "${ROOT_PID}" 2>/dev/null; then
  echo "The recorded process for ${RUN_ID} is no longer active." >&2
  exit 1
fi

descendants() {
  local parent="$1"
  local child
  while IFS= read -r child; do
    [[ -z "${child}" ]] && continue
    descendants "${child}"
    echo "${child}"
  done < <(/usr/bin/pgrep -P "${parent}" 2>/dev/null || true)
}

CHILD_PIDS=()
while IFS= read -r pid; do
  [[ -n "${pid}" ]] && CHILD_PIDS+=("${pid}")
done < <(descendants "${ROOT_PID}")

case "${ACTION}" in
  pause)
    for pid in "${CHILD_PIDS[@]}"; do kill -STOP "${pid}" 2>/dev/null || true; done
    kill -STOP "${ROOT_PID}"
    ;;
  resume)
    kill -CONT "${ROOT_PID}"
    for pid in "${CHILD_PIDS[@]}"; do kill -CONT "${pid}" 2>/dev/null || true; done
    ;;
  stop)
    for pid in "${CHILD_PIDS[@]}"; do kill -TERM "${pid}" 2>/dev/null || true; done
    kill -TERM "${ROOT_PID}"
    ;;
esac

echo "${ACTION} requested for ${RUN_ID} (pid ${ROOT_PID})."
