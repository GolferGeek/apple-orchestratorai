#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-team-smoke-$(date -u +%Y%m%dT%H%M%SZ)}"
MODEL="${MODEL:-qwen3.6:27b-mlx}"
FIXTURE="${FIXTURE:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json}"
LAUNCH_PAYLOAD="${LAUNCH_PAYLOAD:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/launch-payload.json}"
PI_BIN="${PI_BIN:-${ROOT_DIR}/.runtime/pi/packages/coding-agent/dist/cli.js}"
PI_NODE_BIN="${PI_NODE_BIN:-$(command -v node || true)}"
RAW_FILE="${STATE_DIR}/raw-pi-events/${RUN_ID}.workflow-run-team.jsonl"

if [[ -f "${ROOT_DIR}/.runtime/pi-env.sh" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.runtime/pi-env.sh"
fi

for required_file in "${FIXTURE}" "${LAUNCH_PAYLOAD}" "${PI_BIN}" "${ROOT_DIR}/.pi/extensions/workflow-tools/index.ts"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Missing required file: ${required_file}" >&2
    exit 1
  fi
done

if [[ -z "${PI_NODE_BIN}" || ! -x "${PI_NODE_BIN}" ]]; then
  echo "node is required but was not found on PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "${RAW_FILE}")"

prompt="$(node - "${RUN_ID}" "${FIXTURE}" "${LAUNCH_PAYLOAD}" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const [runId, fixturePath, launchPayloadPath] = process.argv.slice(2);
const fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));
const launchPayload = JSON.parse(fs.readFileSync(launchPayloadPath, "utf8"));
const source = fixture.fileSystemDocuments;
const documents = source.filePaths.map((filePath, index) => ({
  id: `doc-${index + 1}`,
  displayName: path.basename(filePath),
  path: path.join(source.baseDirectory, filePath),
  sourceUri: source.sourceUris?.[index] ?? null,
  clientId: source.clientId,
  matterId: source.matterId,
}));
const documentsText = documents.map((document) => ({
  documentId: document.id,
  displayName: document.displayName,
  text: fs.readFileSync(path.resolve(document.path), "utf8").slice(0, 6000),
  extractionMethod: "fixture-text",
}));

const payload = {
  runId,
  workflowId: "legal.document-onboarding",
  workUnitId: "document_onboarding.source_intake",
  teamId: "source-intake-team",
  graphId: "document_onboarding",
  subgraphId: "source_and_intake",
  stageId: "source_intake",
  summary: "Smoke test full source-intake team",
  sharedContext: {
    client: fixture.client,
    matter: fixture.matter,
    launchSource: launchPayload.source,
    fileSystemDocuments: source,
    documents,
    documentsText,
    reviewInstructions: fixture.reviewInstructions,
    classification: fixture.classification,
    modelPolicy: launchPayload.modelPolicy,
  },
  roles: [
    {
      roleId: "source-lead",
      agent: "legal-source-resolver",
      skillId: "legal-document-source",
      task: "Return the source packet using only the supplied sharedContext client, matter, launch source, and document facts.",
      outputEntryType: "source.packet",
      modelTier: "standard",
      timeoutSeconds: 45,
    },
    {
      roleId: "intake-worker",
      agent: "legal-document-intake-agent",
      skillId: "legal-document-intake",
      task: "Return the intake packet using only the supplied sharedContext document references and extracted text.",
      outputEntryType: "intake.packet",
      modelTier: "standard",
      timeoutSeconds: 60,
    },
    {
      roleId: "intake-verifier",
      agent: "legal-quality-reviewer",
      skillId: "legal-document-intake",
      task: "Review the source and intake outputs for schema problems, missing facts, source references, and local-only policy. Return the required quality-review JSON.",
      outputEntryType: "intake.quality_review",
      modelTier: "standard",
      timeoutSeconds: 60,
    },
  ],
};

process.stdout.write(
  [
    "Call workflow_run_team exactly once using this exact JSON payload.",
    "Do not omit sharedContext. Do not call any other tools.",
    "",
    "```json",
    JSON.stringify(payload, null, 2),
    "```",
  ].join("\n")
);
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
  --tools workflow_run_team \
  "${prompt}" > "${RAW_FILE}"

EVENTS_FILE="${STATE_DIR}/events/${RUN_ID}.jsonl"
ENTRIES_FILE="${STATE_DIR}/runs/${RUN_ID}.entries.jsonl"
STATUS_FILE="${STATE_DIR}/runs/${RUN_ID}.status.json"

echo "run-id: ${RUN_ID}"
echo "raw-pi-events: ${RAW_FILE}"
echo "workflow-events: ${EVENTS_FILE}"
echo "run-entries: ${ENTRIES_FILE}"
echo "run-status: ${STATUS_FILE}"

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
print("latest-event:", status.get("latestEventType"))
print("completed-work-units:", ",".join(status.get("completedWorkUnitIds", [])))
print("completed-teams:", ",".join(status.get("completedTeamIds", [])))
print("completed-roles:", ",".join(status.get("completedRoleIds", [])))
PY
else
  echo "Missing status file: ${STATUS_FILE}" >&2
  exit 1
fi
