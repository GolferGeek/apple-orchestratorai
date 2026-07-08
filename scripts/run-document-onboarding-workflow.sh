#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${ROOT_DIR}/.runtime/apple-local-state}"
RUN_ID="${RUN_ID:-run-document-onboarding-$(date -u +%Y%m%dT%H%M%SZ)}"
FIXTURE="${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json"
LAUNCH_PAYLOAD="${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/launch-payload.json"
WORKFLOW="${ROOT_DIR}/workflows/legal/document-onboarding.workflow.json"
EXECUTION_PLAN="${ROOT_DIR}/workflows/legal/document-onboarding.execution-plan.json"
RUN_FILE="${STATE_DIR}/runs/${RUN_ID}.json"
EVENTS_FILE="${STATE_DIR}/events/${RUN_ID}.jsonl"
ENVELOPE_FILE="${STATE_DIR}/display-envelopes/${RUN_ID}.json"
STAGE_DIR="${STATE_DIR}/stage-results/${RUN_ID}"
MODEL="${MODEL:-qwen3.6:35b-a3b-nvfp4}"

if [[ ! -f "${FIXTURE}" ]]; then
  echo "Missing fixture: ${FIXTURE}" >&2
  exit 1
fi

if [[ ! -f "${LAUNCH_PAYLOAD}" ]]; then
  echo "Missing launch payload: ${LAUNCH_PAYLOAD}" >&2
  exit 1
fi

if [[ ! -f "${EXECUTION_PLAN}" ]]; then
  echo "Missing execution plan: ${EXECUTION_PLAN}" >&2
  exit 1
fi

python3 "${ROOT_DIR}/scripts/workflow-state.py" init "${RUN_FILE}" "${EVENTS_FILE}" "${RUN_ID}" "${FIXTURE}"

run_stage() {
  local stage_id="$1"
  local stage_name="$2"
  local stage_skill="$3"
  local output_file="${STAGE_DIR}/${stage_id}.json"

  python3 - "${EVENTS_FILE}" "${RUN_ID}" "${stage_id}" "${EXECUTION_PLAN}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

events_file, run_id, stage_id, execution_plan_file = sys.argv[1:5]
plan = json.load(open(execution_plan_file))
stage = next(item for item in plan["stages"] if item["id"] == stage_id)
primary = next((unit for unit in stage["workUnits"] if not unit.get("optional")), stage["workUnits"][0])
event = {
    "timestamp": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "type": "stage.started",
    "runId": run_id,
    "workflowId": plan["workflowId"],
    "stageId": stage_id,
    "graphId": stage["graphId"],
    "subgraphId": stage.get("subgraphId"),
    "workUnitId": primary["id"],
    "skillId": primary["skillId"],
    "status": "running",
    "summary": f"{stage_id.replace('_', ' ').title()} started.",
    "message": "Hermes is running the workflow skill for this stage.",
    "progress": {"current": 0, "total": 1, "unit": "work_units"},
}
Path(events_file).parent.mkdir(parents=True, exist_ok=True)
with Path(events_file).open("a") as handle:
    handle.write(json.dumps(event, separators=(",", ":")) + "\n")
    unit_event = dict(event)
    unit_event["timestamp"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    unit_event["type"] = "work_unit.started"
    handle.write(json.dumps(unit_event, separators=(",", ":")) + "\n")
PY

  prompt="$(python3 - "${WORKFLOW}" "${FIXTURE}" "${LAUNCH_PAYLOAD}" "${stage_id}" "${stage_name}" "${stage_skill}" <<'PY'
import json
import sys

workflow_path, fixture_path, launch_payload_path, stage_id, stage_name, stage_skill = sys.argv[1:7]
workflow = json.load(open(workflow_path))
fixture = json.load(open(fixture_path))
launch_payload = json.load(open(launch_payload_path))
stage = next(item for item in workflow["runtime"]["observability"]["presentationStages"] if item == stage_id)
summary = {
    "workflowId": workflow["id"],
    "workflowName": workflow["name"],
    "launchPayload": launch_payload,
    "stageId": stage,
    "stageName": stage_name,
    "skill": stage_skill,
    "client": fixture["client"],
    "matter": fixture["matter"],
    "files": fixture["fileSystemDocuments"]["filePaths"],
    "reviewInstructions": fixture["reviewInstructions"],
}
print(
    "You are running one Apple Orchestrator AI workflow stage through Hermes. "
    "Return ONLY one-line valid JSON. No markdown fences, commentary, arrays outside fields, or trailing text. "
    "Use only the provided facts. Do not introduce new parties, laws, fees, or dates. "
    "Do not claim that files, documents, or instructions are missing. The fixture documents are already resolved. "
    "For hitl_review, say the local demo review was approved. For report, say the final display envelope was prepared. "
    "The JSON must have exactly these keys: id, name, status, summary, output. "
    "id must equal the stage id. status must be completed. summary must be under 120 characters. "
    "output must be plain text under 180 characters and must not contain braces, brackets, or escaped quotes. "
    "Stage input: "
    + json.dumps(summary, separators=(",", ":"))
)
PY
)"

  HERMES_JSON_PROMPT="${prompt}" \
  HERMES_JSON_OUTPUT_FILE="${output_file}" \
  HERMES_JSON_REQUIRED_KEYS="id,name,status,summary,output" \
  HERMES_JSON_POLL_COUNT=120 \
  MODEL="${MODEL}" \
  "${ROOT_DIR}/scripts/hermes-json-run.sh"

  python3 "${ROOT_DIR}/scripts/workflow-state.py" stage "${RUN_FILE}" "${EVENTS_FILE}" "${stage_id}" "${output_file}"
}

run_stage "metadata" "Metadata" "legal.shared.extract-document-metadata.v0"
run_stage "classify" "Classify" "legal.shared.clo-route-specialists.v0"
run_stage "specialists" "Specialists" "legal.shared.specialist-review.v0"
run_stage "synthesis" "Synthesis" "legal.workflow.document-onboarding.synthesize-findings.v0"
run_stage "hitl_review" "Human Review" "workflow.request-human-review.v0"
run_stage "report" "Report" "workflow.render-output-packet.v0"

python3 "${ROOT_DIR}/scripts/workflow-state.py" finalize "${RUN_FILE}" "${EVENTS_FILE}" "${ENVELOPE_FILE}"

echo "wrote-run-record: ${RUN_FILE}"
echo "wrote-events: ${EVENTS_FILE}"
echo "wrote-display-envelope: ${ENVELOPE_FILE}"
