#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-document-onboarding-full-$(date -u +%Y%m%dT%H%M%SZ)}"
MODEL="${MODEL:-qwen3.6:27b-mlx}"
PI_BIN="${PI_BIN:-${ROOT_DIR}/.runtime/pi/packages/coding-agent/dist/cli.js}"
PI_NODE_BIN="${PI_NODE_BIN:-$(command -v node || true)}"
REVIEW_ID="${RUN_ID}-attorney-review"
DECISION_FILE="${STATE_DIR}/human-reviews/${REVIEW_ID}.decision.json"
RAW_START_FILE="${STATE_DIR}/raw-pi-events/${RUN_ID}.workflow-start.jsonl"
RAW_WAIT_FILE="${STATE_DIR}/raw-pi-events/${RUN_ID}.human-review-wait.jsonl"

if [[ -f "${ROOT_DIR}/.runtime/pi-env.sh" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.runtime/pi-env.sh"
fi

for required_file in \
  "${PI_BIN}" \
  "${ROOT_DIR}/.pi/extensions/workflow-tools/index.ts" \
  "${ROOT_DIR}/scripts/smoke-workflow-run-team.sh" \
  "${ROOT_DIR}/scripts/smoke-document-onboarding-metadata-team.sh" \
  "${ROOT_DIR}/scripts/smoke-document-onboarding-routing-team.sh" \
  "${ROOT_DIR}/scripts/smoke-document-onboarding-specialist-team.sh" \
  "${ROOT_DIR}/scripts/smoke-document-onboarding-synthesis-team.sh" \
  "${ROOT_DIR}/scripts/smoke-document-onboarding-hitl-team.sh" \
  "${ROOT_DIR}/scripts/smoke-document-onboarding-output-team.sh"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Missing required file: ${required_file}" >&2
    exit 1
  fi
done

if [[ -z "${PI_NODE_BIN}" || ! -x "${PI_NODE_BIN}" ]]; then
  echo "node is required but was not found on PATH" >&2
  exit 1
fi

mkdir -p "${STATE_DIR}/raw-pi-events" "${STATE_DIR}/human-reviews"

start_prompt="$(node - "${RUN_ID}" <<'NODE'
const [runId] = process.argv.slice(2);
const payload = {
  runId,
  workflowId: "legal.document-onboarding",
  type: "workflow.started",
  status: "running",
  summary: "Document Onboarding full smoke started",
  raw: {
    profileId: "legal-dev",
    client: { id: "client-acme-robotics", name: "Acme Robotics LLC" },
    matter: { id: "matter-vendor-renewal-2026", name: "Vendor Agreement Renewal" }
  }
};
process.stdout.write([
  "Call workflow_emit_event exactly once using this exact JSON payload.",
  "Do not call any other tools.",
  "",
  "```json",
  JSON.stringify(payload, null, 2),
  "```",
].join("\n"));
NODE
)"

"${PI_NODE_BIN}" "${PI_BIN}" \
  --mode json \
  -p \
  --no-session \
  --provider ollama \
  --api-key ollama \
  --model "${MODEL}" \
  --no-builtin-tools \
  --extension "${ROOT_DIR}/.pi/extensions/workflow-tools/index.ts" \
  --tools workflow_emit_event \
  "${start_prompt}" > "${RAW_START_FILE}"

echo "run-id: ${RUN_ID}"
echo "workflow-started"

require_healthy_run() {
  python3 - "${STATE_DIR}/runs/${RUN_ID}.status.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
status = json.loads(path.read_text())
if status.get("status") in {"failed", "stopped", "cancelled"}:
    print(f"Workflow stopped after {status.get('latestEventType')}: {status.get('latestSummary')}", file=sys.stderr)
    sys.exit(1)
PY
}

RUN_ID="${RUN_ID}" MODEL="${MODEL}" "${ROOT_DIR}/scripts/smoke-workflow-run-team.sh"
require_healthy_run
RUN_ID="${RUN_ID}" MODEL="${MODEL}" "${ROOT_DIR}/scripts/smoke-document-onboarding-metadata-team.sh"
require_healthy_run
RUN_ID="${RUN_ID}" MODEL="${MODEL}" "${ROOT_DIR}/scripts/smoke-document-onboarding-routing-team.sh"
require_healthy_run
RUN_ID="${RUN_ID}" MODEL="${MODEL}" "${ROOT_DIR}/scripts/smoke-document-onboarding-specialist-team.sh"
require_healthy_run
RUN_ID="${RUN_ID}" MODEL="${MODEL}" "${ROOT_DIR}/scripts/smoke-document-onboarding-synthesis-team.sh"
require_healthy_run
RUN_ID="${RUN_ID}" MODEL="${MODEL}" "${ROOT_DIR}/scripts/smoke-document-onboarding-hitl-team.sh"
require_healthy_run

cat > "${DECISION_FILE}" <<JSON
{
  "runId": "${RUN_ID}",
  "workflowId": "legal.document-onboarding",
  "reviewId": "${REVIEW_ID}",
  "decision": "approve",
  "reviewer": "Full Smoke Reviewer",
  "note": "Approved by simulated full-smoke decision.",
  "edits": [
    {
      "segmentId": "risk-liability-cap",
      "note": "Keep liability cap issue prominent."
    },
    {
      "segmentId": "risk-operational-data",
      "note": "Require operational data scope confirmation."
    }
  ],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

wait_prompt="$(node - "${REVIEW_ID}" <<'NODE'
const [reviewId] = process.argv.slice(2);
const payload = { reviewId };
process.stdout.write([
  "Call workflow_wait_for_human_review exactly once using this exact JSON payload.",
  "Do not call any other tools.",
  "",
  "```json",
  JSON.stringify(payload, null, 2),
  "```",
].join("\n"));
NODE
)"

"${PI_NODE_BIN}" "${PI_BIN}" \
  --mode json \
  -p \
  --no-session \
  --provider ollama \
  --api-key ollama \
  --model "${MODEL}" \
  --no-builtin-tools \
  --extension "${ROOT_DIR}/.pi/extensions/workflow-tools/index.ts" \
  --tools workflow_wait_for_human_review \
  "${wait_prompt}" > "${RAW_WAIT_FILE}"

echo "human-review-decision-loaded: ${REVIEW_ID}"

RUN_ID="${RUN_ID}" MODEL="${MODEL}" "${ROOT_DIR}/scripts/smoke-document-onboarding-output-team.sh"

EVENTS_FILE="${STATE_DIR}/events/${RUN_ID}.jsonl"
ENTRIES_FILE="${STATE_DIR}/runs/${RUN_ID}.entries.jsonl"
STATUS_FILE="${STATE_DIR}/runs/${RUN_ID}.status.json"
RUN_RECORD_FILE="${STATE_DIR}/runs/${RUN_ID}.json"
ARTIFACT_FILE="${STATE_DIR}/artifacts/${RUN_ID}/document-onboarding-report.md"

echo "workflow-events: ${EVENTS_FILE}"
echo "run-entries: ${ENTRIES_FILE}"
echo "run-status: ${STATUS_FILE}"
echo "run-record: ${RUN_RECORD_FILE}"
echo "artifact: ${ARTIFACT_FILE}"

python3 - "${STATUS_FILE}" "${ENTRIES_FILE}" "${EVENTS_FILE}" "${RUN_RECORD_FILE}" <<'PY'
import json
import sys
from pathlib import Path

status_path, entries_path, events_path, record_path = map(Path, sys.argv[1:5])
status = json.loads(status_path.read_text())
record = json.loads(record_path.read_text())
print("status:", status.get("status"))
print("latest-event:", status.get("latestEventType"))
print("completed-work-units:", ",".join(status.get("completedWorkUnitIds", [])))
print("completed-teams:", ",".join(status.get("completedTeamIds", [])))
print("completed-roles:", ",".join(status.get("completedRoleIds", [])))
print("event-count:", len(events_path.read_text().splitlines()))
print("entry-count:", len(entries_path.read_text().splitlines()))
print("swift-record-status:", record.get("status"))
print("swift-record-stages:", ",".join(f"{stage['id']}={stage['status']}" for stage in record.get("stages", [])))
print("swift-record-outputs:", len(record.get("outputs", [])))
PY

if [[ ! -f "${ARTIFACT_FILE}" ]]; then
  echo "Missing artifact file: ${ARTIFACT_FILE}" >&2
  exit 1
fi
