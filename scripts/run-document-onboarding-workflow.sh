#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-document-onboarding-$(date -u +%Y%m%dT%H%M%SZ)}"
FIXTURE="${FIXTURE:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json}"
LAUNCH_PAYLOAD="${LAUNCH_PAYLOAD:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/launch-payload.json}"
MODEL="${MODEL:-qwen3.6:35b-mlx}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"
COORDINATOR_AGENT="${ROOT_DIR}/.pi/agents/legal-document-onboarding-coordinator.md"
WORKFLOW_AGENT="${ROOT_DIR}/workflows/legal/document-onboarding.workflow-agent.md"

for required_file in "${LAUNCH_PAYLOAD}" "${COORDINATOR_AGENT}" "${WORKFLOW_AGENT}"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Missing required file: ${required_file}" >&2
    exit 1
  fi
done

prompt="$(node - "${RUN_ID}" "${FIXTURE}" "${LAUNCH_PAYLOAD}" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [runId, fixturePath, launchPayloadPath] = process.argv.slice(2);
const fixture = fs.existsSync(fixturePath) ? JSON.parse(fs.readFileSync(fixturePath, "utf8")) : {};
const launchPayload = JSON.parse(fs.readFileSync(launchPayloadPath, "utf8"));
const selectedPaths = Array.isArray(launchPayload.source?.filePaths) ? launchPayload.source.filePaths : [];
const documents = selectedPaths.map((filePath, index) => ({
  id: launchPayload.source?.documentIds?.[index] ?? `document-${index + 1}`,
  displayName: launchPayload.source?.documentLabels?.[index] ?? path.basename(filePath),
  path: filePath,
  sourceUri: launchPayload.source?.sourceUris?.[index] ?? null,
}));

const source = {
  client: launchPayload.source?.client ?? fixture.client ?? null,
  matter: launchPayload.source?.matter ?? fixture.matter ?? null,
  launchPayload,
  documents,
  reviewInstructions: fixture.reviewInstructions ?? [],
  classification: launchPayload.classification ?? fixture.classification ?? "user-selected-local-files",
  modelPolicy: launchPayload.modelPolicy,
};

process.stdout.write(
  [
    "Run the Document Onboarding workflow using the active legal-document-onboarding coordinator agent.",
    `Run ID: ${runId}`,
    "",
    "Launch facts:",
    "```json",
    JSON.stringify(source, null, 2),
    "```",
    "",
    "The workflow-agent Markdown supplied as the system prompt is the source of truth for workflow structure. Use Pi skills, project-local agents, and workflow tools directly.",
  ].join("\n")
);
NODE
)"

python3 "${ROOT_DIR}/scripts/smoke-pi-rpc-events.py" \
  --run-id "${RUN_ID}" \
  --workflow-id "legal.document-onboarding" \
  --stage-id "document_onboarding" \
  --graph-id "document_onboarding" \
  --work-unit-id "document_onboarding.coordinator" \
  --skill-id "legal-document-onboarding" \
  --team-id "legal-document-onboarding" \
  --role-id "coordinator" \
  --state-dir "${STATE_DIR}" \
  --model "${MODEL}" \
  --prompt "${prompt}" \
  --timeout-seconds "${TIMEOUT_SECONDS}" \
  --stop-on "workflow.completed,runtime.error,human_review.requested" \
  --no-builtin-tools \
  --extension "${ROOT_DIR}/.pi/extensions/workflow-tools/index.ts" \
  --skill "${ROOT_DIR}/.pi/skills" \
  --append-system-prompt "${COORDINATOR_AGENT}" \
  --append-system-prompt "${WORKFLOW_AGENT}" \
  --tools "workflow_call_agent,workflow_run_team,workflow_call_dynamic_agent,workflow_promote_dynamic_agent,workflow_emit_event,workflow_append_run_entry,workflow_write_plan,workflow_resolve_client_matter,workflow_list_source_options,workflow_resolve_documents,workflow_extract_text,workflow_read_file,workflow_request_human_review,workflow_wait_for_human_review,workflow_write_artifact,workflow_structured_output"
