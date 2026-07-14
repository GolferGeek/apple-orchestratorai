#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-synthesis-team-smoke-$(date -u +%Y%m%dT%H%M%SZ)}"
MODEL="${MODEL:-qwen3.6:27b-mlx}"
FIXTURE="${FIXTURE:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json}"
LAUNCH_PAYLOAD="${LAUNCH_PAYLOAD:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/launch-payload.json}"
PI_BIN="${PI_BIN:-${ROOT_DIR}/.runtime/pi/packages/coding-agent/dist/cli.js}"
PI_NODE_BIN="${PI_NODE_BIN:-$(command -v node || true)}"
RAW_FILE="${STATE_DIR}/raw-pi-events/${RUN_ID}.synthesis-team.jsonl"

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
  text: fs.readFileSync(path.resolve(document.path), "utf8").slice(0, 5000),
  extractionMethod: "fixture-text",
}));

const metadataPacket = {
  documentsMetadata: [
    {
      documentId: "doc-1",
      documentType: { type: "engagement-letter", confidence: 0.92 },
      parties: { client: "Acme Robotics LLC", vendor: "Northwind Supply Inc." },
      obligations: ["Review commercial terms, confidentiality, data handling, renewal pricing, and dispute resolution."],
      sensitivityFlags: ["confidentiality", "data-handling"],
      sourceRefs: ["doc-1:engagement-letter.md"],
    },
    {
      documentId: "doc-2",
      documentType: { type: "vendor-renewal-summary", confidence: 0.95 },
      dates: { effectiveDate: "2026-07-01", term: "24 months", noticePeriod: "60 days written notice" },
      parties: { client: "Acme Robotics LLC", vendor: "Northwind Supply Inc." },
      obligations: [
        "Annual spend increases from USD 420,000 to USD 510,000.",
        "Vendor may process operational data for support and analytics.",
        "Confidential information must be protected using commercially reasonable safeguards.",
        "Liability is capped at fees paid in the previous 12 months.",
        "Disputes proceed to confidential arbitration in Cook County, Illinois.",
      ],
      sensitivityFlags: ["operational-data", "confidentiality", "liability-cap", "arbitration"],
      warnings: ["Confirm whether operational data includes personal information."],
      sourceRefs: ["doc-2:vendor-renewal-summary.md"],
    },
  ],
};

const routingDecision = {
  selectedLanes: ["contract", "compliance", "ip", "privacy", "corporate", "litigation"],
  confidence: 0.93,
  humanReviewFlags: ["confirmOperationalDataScope", "confirmArbitrationAcceptability", "confirmLiabilityCapForDataIncidents"],
  sourceRefs: ["doc-1:engagement-letter.md", "doc-2:vendor-renewal-summary.md"],
};

const specialistOutputs = {
  contract: {
    risks: ["Liability cap may be too low for data incidents.", "No explicit SLA or indemnity terms."],
    recommendedActions: ["Negotiate data incident carveout.", "Confirm renewal notice calendar."],
    citations: ["doc-2:vendor-renewal-summary.md"],
    confidence: 0.88,
  },
  compliance: {
    risks: ["Operational data processing and vendor controls need confirmation."],
    recommendedActions: ["Request security/control documentation and audit rights."],
    citations: ["doc-2:vendor-renewal-summary.md"],
    confidence: 0.83,
  },
  ip: {
    risks: ["Operational data and confidential information may include trade secrets or proprietary know-how."],
    recommendedActions: ["Clarify ownership, permitted use, and confidentiality survival."],
    citations: ["doc-2:vendor-renewal-summary.md"],
    confidence: 0.8,
  },
  privacy: {
    risks: ["Operational data may include personal information; DPA and breach terms are not visible."],
    recommendedActions: ["Confirm whether personal data is processed and require privacy/security terms if so."],
    citations: ["doc-2:vendor-renewal-summary.md"],
    confidence: 0.86,
  },
  corporate: {
    risks: ["Material annual spend increase may require approval authority review."],
    recommendedActions: ["Confirm signatory authority and approval thresholds."],
    citations: ["doc-1:engagement-letter.md", "doc-2:vendor-renewal-summary.md"],
    confidence: 0.78,
  },
  litigation: {
    risks: ["Confidential arbitration in Cook County and liability cap may limit remedies."],
    recommendedActions: ["Confirm dispute forum is acceptable and preserve evidence requirements."],
    citations: ["doc-2:vendor-renewal-summary.md"],
    confidence: 0.84,
  },
  qualityReview: {
    status: "warning",
    findings: ["Citations are present but several conclusions require attorney confirmation."],
    humanReviewFlags: ["confirmOperationalDataScope", "confirmArbitrationAcceptability", "confirmLiabilityCapForDataIncidents"],
    confidence: 0.82,
  },
  arbitration: {
    selectedPosition: { status: "no material conflict", note: "Attorney review is required for business/legal judgment points." },
    requiresHumanDecision: true,
    confidence: 0.8,
  },
};

const payload = {
  runId,
  workflowId: "legal.document-onboarding",
  workUnitId: "document_onboarding.synthesis",
  teamId: "synthesis-team",
  graphId: "synthesis_review_and_report",
  subgraphId: "synthesis",
  stageId: "synthesis",
  summary: "Smoke test synthesis team",
  sharedContext: {
    client: fixture.client,
    matter: fixture.matter,
    documents,
    documentsText,
    metadataPacket,
    routingDecision,
    specialistOutputs,
    reviewInstructions: fixture.reviewInstructions,
    classification: fixture.classification,
    modelPolicy: launchPayload.modelPolicy,
  },
  roles: [
    {
      roleId: "synthesis-lead",
      agent: "legal-synthesis-agent",
      skillId: "legal-synthesis",
      task: "Synthesize metadata, routing, and specialist outputs into the required synthesis JSON with executiveSummary, riskMatrix, crossDocumentFindings, recommendedActions, conflicts, humanReviewFlags, and confidence.",
      outputEntryType: "synthesis.packet",
      modelTier: "deep",
      timeoutSeconds: 120,
    },
    {
      roleId: "synthesis-verifier",
      agent: "legal-quality-reviewer",
      skillId: "legal-synthesis",
      task: "Review the synthesis for unsupported conclusions, missing citations, unresolved conflicts, low confidence, human-review flags, schema problems, and local-only policy. Return the required quality-review JSON.",
      outputEntryType: "synthesis.quality_review",
      modelTier: "standard",
      timeoutSeconds: 75,
    },
    {
      roleId: "synthesis-arbitrator",
      agent: "legal-arbitrator",
      skillId: "legal-synthesis",
      task: "Arbitrate only if the quality reviewer or synthesis packet shows unsupported conclusions, conflicts, or missing citations. Otherwise record that arbitration is not required. Return the required arbitration JSON.",
      outputEntryType: "synthesis.arbitration",
      modelTier: "deep",
      timeoutSeconds: 90,
      required: false,
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
