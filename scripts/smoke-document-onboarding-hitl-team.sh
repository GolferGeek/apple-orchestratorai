#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-hitl-team-smoke-$(date -u +%Y%m%dT%H%M%SZ)}"
MODEL="${MODEL:-qwen3.6:27b-mlx}"
FIXTURE="${FIXTURE:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json}"
LAUNCH_PAYLOAD="${LAUNCH_PAYLOAD:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/launch-payload.json}"
PI_BIN="${PI_BIN:-${ROOT_DIR}/.runtime/pi/packages/coding-agent/dist/cli.js}"
PI_NODE_BIN="${PI_NODE_BIN:-$(command -v node || true)}"
RAW_TEAM_FILE="${STATE_DIR}/raw-pi-events/${RUN_ID}.hitl-team.jsonl"
RAW_REVIEW_FILE="${STATE_DIR}/raw-pi-events/${RUN_ID}.human-review-request.jsonl"

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

mkdir -p "$(dirname "${RAW_TEAM_FILE}")"

team_prompt="$(node - "${RUN_ID}" "${FIXTURE}" "${LAUNCH_PAYLOAD}" <<'NODE'
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
  clientId: source.clientId,
  matterId: source.matterId,
}));

const synthesis = {
  executiveSummary: "Acme should not approve the Northwind renewal without attorney review of operational data scope, liability cap, arbitration forum, approval authority, and privacy/security terms.",
  riskMatrix: [
    { risk: "Liability cap may be too low for data incidents", severity: "high", owner: "contract/privacy", citations: ["doc-2:vendor-renewal-summary.md"] },
    { risk: "Operational data may include personal information", severity: "high", owner: "privacy/compliance", citations: ["doc-2:vendor-renewal-summary.md"] },
    { risk: "Confidential arbitration limits dispute strategy", severity: "medium", owner: "litigation", citations: ["doc-2:vendor-renewal-summary.md"] },
  ],
  recommendedActions: [
    "Confirm whether operational data includes personal information.",
    "Negotiate data incident carveout or higher liability cap.",
    "Confirm signatory authority for USD 510,000 annual spend.",
    "Confirm arbitration forum and confidentiality are acceptable.",
  ],
  conflicts: [],
  humanReviewFlags: ["confirmOperationalDataScope", "confirmArbitrationAcceptability", "confirmLiabilityCapForDataIncidents", "confirmApprovalAuthority"],
  confidence: 0.84,
};

const payload = {
  runId,
  workflowId: "legal.document-onboarding",
  workUnitId: "document_onboarding.human_review",
  teamId: "human-review-team",
  graphId: "synthesis_review_and_report",
  subgraphId: "attorney_review",
  stageId: "hitl_review",
  summary: "Smoke test human review team",
  sharedContext: {
    client: fixture.client,
    matter: fixture.matter,
    documents,
    synthesis,
    reviewInstructions: fixture.reviewInstructions,
    classification: fixture.classification,
    modelPolicy: launchPayload.modelPolicy,
    allowedDecisions: ["approve", "modify", "reject", "request_changes"],
  },
  roles: [
    {
      roleId: "hitl-lead",
      agent: "legal-hitl-coordinator",
      skillId: "legal-human-review",
      task: "Create an Apple app human-review payload for the attorney/student. Include summary, segmented editable review items, citations, questions, humanReviewFlags, and allowed decisions. Return a compact JSON review payload only.",
      outputEntryType: "human_review.payload",
      modelTier: "standard",
      timeoutSeconds: 60,
    },
  ],
};

process.stdout.write(
  [
    "Call workflow_run_team exactly once using this exact JSON payload.",
    "Do not call any other tools.",
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
  "${team_prompt}" > "${RAW_TEAM_FILE}"

review_prompt="$(node - "${RUN_ID}" <<'NODE'
const [runId] = process.argv.slice(2);
const payload = {
  runId,
  workflowId: "legal.document-onboarding",
  reviewId: `${runId}-attorney-review`,
  title: "Attorney review required for Acme / Northwind renewal",
  allowedDecisions: ["approve", "modify", "reject", "request_changes"],
  payload: {
    workflowId: "legal.document-onboarding",
    runId,
    summary: "Review legal risks before final output is generated.",
    segments: [
      { id: "risk-liability-cap", title: "Liability cap", editable: true, decisionRequired: true },
      { id: "risk-operational-data", title: "Operational data scope", editable: true, decisionRequired: true },
      { id: "risk-arbitration", title: "Arbitration forum", editable: true, decisionRequired: false },
      { id: "approval-authority", title: "Approval authority", editable: true, decisionRequired: true },
    ],
    humanReviewFlags: ["confirmOperationalDataScope", "confirmArbitrationAcceptability", "confirmLiabilityCapForDataIncidents", "confirmApprovalAuthority"],
  },
};

process.stdout.write(
  [
    "Call workflow_request_human_review exactly once using this exact JSON payload.",
    "Do not call any other tools.",
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
  --tools workflow_request_human_review \
  "${review_prompt}" > "${RAW_REVIEW_FILE}"

EVENTS_FILE="${STATE_DIR}/events/${RUN_ID}.jsonl"
ENTRIES_FILE="${STATE_DIR}/runs/${RUN_ID}.entries.jsonl"
STATUS_FILE="${STATE_DIR}/runs/${RUN_ID}.status.json"
REVIEW_FILE="${STATE_DIR}/human-reviews/${RUN_ID}-attorney-review.json"

echo "run-id: ${RUN_ID}"
echo "raw-pi-events-team: ${RAW_TEAM_FILE}"
echo "raw-pi-events-review: ${RAW_REVIEW_FILE}"
echo "workflow-events: ${EVENTS_FILE}"
echo "run-entries: ${ENTRIES_FILE}"
echo "run-status: ${STATUS_FILE}"
echo "human-review: ${REVIEW_FILE}"

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
print("latest-event:", status.get("latestEventType"))
print("completed-work-units:", ",".join(status.get("completedWorkUnitIds", [])))
print("completed-teams:", ",".join(status.get("completedTeamIds", [])))
print("completed-roles:", ",".join(status.get("completedRoleIds", [])))
pending = status.get("pendingHumanReview") or {}
print("pending-review:", pending.get("reviewId"))
PY
else
  echo "Missing status file: ${STATUS_FILE}" >&2
  exit 1
fi

if [[ ! -f "${REVIEW_FILE}" ]]; then
  echo "Missing human review file: ${REVIEW_FILE}" >&2
  exit 1
fi
