#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-specialist-team-smoke-$(date -u +%Y%m%dT%H%M%SZ)}"
MODEL="${MODEL:-qwen3.6:27b-mlx}"
FIXTURE="${FIXTURE:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json}"
LAUNCH_PAYLOAD="${LAUNCH_PAYLOAD:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/launch-payload.json}"
PI_BIN="${PI_BIN:-${ROOT_DIR}/.runtime/pi/packages/coding-agent/dist/cli.js}"
PI_NODE_BIN="${PI_NODE_BIN:-$(command -v node || true)}"
RAW_FILE="${STATE_DIR}/raw-pi-events/${RUN_ID}.specialist-team.jsonl"

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
      dates: { letterDate: "2026-06-15" },
      parties: { client: "Acme Robotics LLC", vendor: "Northwind Supply Inc." },
      obligations: ["Review commercial terms, confidentiality, data handling, renewal pricing, and dispute resolution."],
      sensitivityFlags: ["confidentiality", "data-handling"],
      confidence: { overall: 0.9 },
      warnings: [],
      sourceRefs: ["doc-1:engagement-letter.md"],
    },
    {
      documentId: "doc-2",
      documentType: { type: "vendor-renewal-summary", confidence: 0.95 },
      dates: { effectiveDate: "2026-07-01", term: "24 months", noticePeriod: "60 days written notice" },
      parties: { client: "Acme Robotics LLC", vendor: "Northwind Supply Inc." },
      deadlines: ["Auto-renewal notice deadline: 60 days before renewal"],
      obligations: [
        "Annual spend increases from USD 420,000 to USD 510,000.",
        "Vendor may process operational data for support and analytics.",
        "Confidential information must be protected using commercially reasonable safeguards.",
        "Liability is capped at fees paid in the previous 12 months.",
        "Disputes proceed to confidential arbitration in Cook County, Illinois.",
      ],
      sensitivityFlags: ["operational-data", "confidentiality", "liability-cap", "arbitration"],
      confidence: { overall: 0.94 },
      warnings: ["Confirm whether operational data includes personal information."],
      sourceRefs: ["doc-2:vendor-renewal-summary.md"],
    },
  ],
};

const routingDecision = {
  selectedLanes: ["contract", "compliance", "ip", "privacy", "corporate", "litigation"],
  laneRationales: {
    contract: "Vendor renewal terms, pricing, auto-renewal, liability, confidentiality, and dispute resolution require contract review.",
    compliance: "Vendor controls, data handling, recordkeeping, and high-value commercial obligations require compliance review.",
    ip: "Confidential information and operational data may include proprietary know-how or trade secrets.",
    privacy: "Operational data processing may include personal information and needs privacy/data-processing review.",
    corporate: "Material vendor renewal and increased annual spend may need authority and approval review.",
    litigation: "Liability cap, arbitration, venue, and dispute process require litigation risk review.",
  },
  alternatives: ["employment", "real-estate"],
  documentTypeMap: { "doc-1": "engagement-letter", "doc-2": "vendor-renewal-summary" },
  confidence: 0.93,
  humanReviewFlags: ["confirmOperationalDataScope", "confirmArbitrationAcceptability", "confirmLiabilityCapForDataIncidents"],
  sourceRefs: ["doc-1:engagement-letter.md", "doc-2:vendor-renewal-summary.md"],
};

const laneRoles = [
  ["contract-specialist", "legal-contract-specialist", "contract", "specialist.contract", "Review contract terms, renewal, pricing, confidentiality, liability cap, governing law, arbitration, risk, citations, and recommended actions."],
  ["compliance-specialist", "legal-compliance-specialist", "compliance", "specialist.compliance", "Review compliance, controls, audit, recordkeeping, vendor obligations, data handling, and policy issues."],
  ["ip-specialist", "legal-ip-specialist", "ip", "specialist.ip", "Review IP, confidential information, proprietary operational data, trade secret handling, and ownership/license concerns."],
  ["privacy-specialist", "legal-privacy-specialist", "privacy", "specialist.privacy", "Review privacy, personal information, operational data processing, security, breach, and data processing concerns."],
  ["corporate-specialist", "legal-corporate-specialist", "corporate", "specialist.corporate", "Review corporate authority, approval, governance, signatory, and material spend concerns."],
  ["litigation-specialist", "legal-litigation-specialist", "litigation", "specialist.litigation", "Review dispute resolution, arbitration, venue, liability cap, evidence, deadlines, and litigation risk."],
];

const payload = {
  runId,
  workflowId: "legal.document-onboarding",
  workUnitId: "document_onboarding.specialist_review",
  teamId: "specialist-panel-team",
  graphId: "document_onboarding",
  subgraphId: "specialist_review",
  stageId: "specialists",
  summary: "Smoke test selected specialist panel team",
  sharedContext: {
    client: fixture.client,
    matter: fixture.matter,
    documents,
    documentsText,
    metadataPacket,
    routingDecision,
    reviewInstructions: fixture.reviewInstructions,
    classification: fixture.classification,
    modelPolicy: launchPayload.modelPolicy,
  },
  roles: [
    ...laneRoles.map(([roleId, agent, lane, outputEntryType, task]) => ({
      roleId,
      agent,
      skillId: "legal-specialist-review",
      task: `${task} Return only the legal-specialist lane JSON for lane '${lane}' with findings, risks, recommendedActions, citations, confidence, and humanReviewFlags.`,
      outputEntryType,
      modelTier: "standard",
      timeoutSeconds: 75,
      required: false,
    })),
    {
      roleId: "specialist-verifier",
      agent: "legal-quality-reviewer",
      skillId: "legal-specialist-review",
      task: "Review all specialist lane outputs for missing citations, unsupported conclusions, conflicts, schema problems, confidence, human-review flags, and local-only policy. Return the required quality-review JSON.",
      outputEntryType: "specialist.quality_review",
      modelTier: "standard",
      timeoutSeconds: 75,
    },
    {
      roleId: "specialist-arbitrator",
      agent: "legal-arbitrator",
      skillId: "legal-specialist-review",
      task: "Arbitrate only if the quality reviewer or prior specialist outputs show conflicts or unsupported conclusions. Otherwise record that arbitration is not required. Return the required arbitration JSON.",
      outputEntryType: "specialist.arbitration",
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
