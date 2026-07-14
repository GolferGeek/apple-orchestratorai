#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-output-team-smoke-$(date -u +%Y%m%dT%H%M%SZ)}"
PI_NODE_BIN="${PI_NODE_BIN:-$(command -v node || true)}"
FINAL_PACKET_FILE="${STATE_DIR}/output-packets/${RUN_ID}.document-onboarding-final.json"

for required_file in "${ROOT_DIR}/scripts/build-document-onboarding-final-report.js"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Missing required file: ${required_file}" >&2
    exit 1
  fi
done

if [[ -z "${PI_NODE_BIN}" || ! -x "${PI_NODE_BIN}" ]]; then
  echo "node is required but was not found on PATH" >&2
  exit 1
fi

"${PI_NODE_BIN}" "${ROOT_DIR}/scripts/build-document-onboarding-final-report.js" "${RUN_ID}" "${STATE_DIR}" --publish > /dev/null

EVENTS_FILE="${STATE_DIR}/events/${RUN_ID}.jsonl"
ENTRIES_FILE="${STATE_DIR}/runs/${RUN_ID}.entries.jsonl"
STATUS_FILE="${STATE_DIR}/runs/${RUN_ID}.status.json"
ARTIFACT_FILE="${STATE_DIR}/artifacts/${RUN_ID}/document-onboarding-report.md"

echo "run-id: ${RUN_ID}"
echo "workflow-events: ${EVENTS_FILE}"
echo "run-entries: ${ENTRIES_FILE}"
echo "run-status: ${STATUS_FILE}"
echo "artifact: ${ARTIFACT_FILE}"

if [[ -f "${EVENTS_FILE}" ]]; then
  echo "event-count: $(wc -l < "${EVENTS_FILE}" | tr -d ' ')"
else
  echo "Missing events file: ${EVENTS_FILE}" >&2
  exit 1
fi

if [[ -f "${ENTRIES_FILE}" ]]; then
  echo "entry-count: $(wc -l < "${ENTRIES_FILE}" | tr -d ' ')"
else
  echo "Missing entries file: ${ENTRIES_FILE}" >&2
  exit 1
fi

if [[ -f "${STATUS_FILE}" ]]; then
  python3 - "${STATUS_FILE}" <<'PY'
import json
import sys

status = json.load(open(sys.argv[1]))
print("status:", status.get("status"))
print("completed-work-units:", ",".join(status.get("completedWorkUnitIds", [])))
print("completed-teams:", ",".join(status.get("completedTeamIds", [])))
print("completed-roles:", ",".join(status.get("completedRoleIds", [])))
print("artifact-count:", len(status.get("artifacts", [])))
outputs = status.get("outputs") or {}
print("output-status:", outputs.get("validation", {}).get("status"))
PY
else
  echo "Missing status file: ${STATUS_FILE}" >&2
  exit 1
fi

if [[ ! -f "${ARTIFACT_FILE}" ]]; then
  echo "Missing artifact file: ${ARTIFACT_FILE}" >&2
  exit 1
fi
