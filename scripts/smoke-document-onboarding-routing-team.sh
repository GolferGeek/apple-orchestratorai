#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
RUN_ID="${RUN_ID:-run-routing-team-smoke-$(date -u +%Y%m%dT%H%M%SZ)}"
MODEL="${MODEL:-qwen3.6:27b-mlx}"
FIXTURE="${FIXTURE:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json}"
LAUNCH_PAYLOAD="${LAUNCH_PAYLOAD:-${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/launch-payload.json}"
PI_BIN="${PI_BIN:-${ROOT_DIR}/.runtime/pi/packages/coding-agent/dist/cli.js}"
PI_NODE_BIN="${PI_NODE_BIN:-$(command -v node || true)}"
RAW_FILE="${STATE_DIR}/raw-pi-events/${RUN_ID}.routing-team.jsonl"

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

const metadataPacket = {
  documentsMetadata: [
    {
      documentId: "doc-1",
      documentType: {
        type: "engagement-letter",
        confidence: 0.92,
        alternatives: ["matter-opening-letter"],
        reasoning: "The document confirms the client, matter, date, and scope of review.",
      },
      sections: { title: "Engagement Letter", scope: "Vendor renewal packet review" },
      signatures: { signatories: ["Jordan Lee, General Counsel, Acme Robotics LLC"] },
      dates: { letterDate: "2026-06-15" },
      parties: { client: "Acme Robotics LLC", vendor: "Northwind Supply Inc." },
      deadlines: [],
      obligations: ["Review commercial terms, confidentiality, data handling, renewal pricing, and dispute resolution provisions."],
      sensitivityFlags: ["confidentiality", "data-handling"],
      confidence: { overall: 0.9 },
      warnings: [],
      sourceRefs: ["doc-1:engagement-letter.md"],
    },
    {
      documentId: "doc-2",
      documentType: {
        type: "vendor-renewal-summary",
        confidence: 0.95,
        alternatives: ["commercial-contract-summary"],
        reasoning: "The document lists renewal terms, pricing, data processing, liability cap, arbitration, and review concerns.",
      },
      sections: { title: "Vendor Renewal Summary", keyTerms: "Annual spend, data processing, confidentiality, liability cap, arbitration" },
      signatures: {},
      dates: { effectiveDate: "2026-07-01", term: "24 months", noticePeriod: "60 days written notice" },
      parties: { client: "Acme Robotics LLC", vendor: "Northwind Supply Inc." },
      deadlines: ["Auto-renewal notice deadline: 60 days before renewal"],
      obligations: [
        "Vendor may process operational data for support and analytics.",
        "Confidential information must be protected using commercially reasonable safeguards.",
        "Disputes proceed to confidential arbitration in Cook County, Illinois.",
      ],
      sensitivityFlags: ["operational-data", "confidentiality", "liability-cap", "arbitration"],
      confidence: { overall: 0.94 },
      warnings: ["Confirm whether operational data includes personal information."],
      sourceRefs: ["doc-2:vendor-renewal-summary.md"],
    },
  ],
};

const payload = {
  runId,
  workflowId: "legal.document-onboarding",
  workUnitId: "document_onboarding.routing",
  teamId: "routing-team",
  graphId: "document_onboarding",
  subgraphId: "clo_routing",
  stageId: "routing",
  summary: "Smoke test routing team with arbitration role",
  sharedContext: {
    client: fixture.client,
    matter: fixture.matter,
    documents,
    documentsText,
    metadataPacket,
    reviewInstructions: fixture.reviewInstructions,
    classification: fixture.classification,
    modelPolicy: launchPayload.modelPolicy,
    availableLanes: ["contract", "compliance", "ip", "privacy", "employment", "corporate", "litigation", "real-estate"],
  },
  roles: [
    {
      roleId: "routing-lead",
      agent: "legal-clo-router",
      skillId: "legal-clo-routing",
      task: "Route this legal document packet to every required specialist lane using sharedContext.metadataPacket and documentsText. Return only the required routingDecision JSON packet.",
      outputEntryType: "routing.packet",
      modelTier: "standard",
      timeoutSeconds: 60,
    },
    {
      roleId: "routing-verifier",
      agent: "legal-quality-reviewer",
      skillId: "legal-clo-routing",
      task: "Review the routing decision for narrowness, unsupported lanes, missing sourceRefs, metadata inconsistency, and local-only policy. Return the required quality-review JSON.",
      outputEntryType: "routing.quality_review",
      modelTier: "standard",
      timeoutSeconds: 60,
    },
    {
      roleId: "routing-arbitrator",
      agent: "legal-arbitrator",
      skillId: "legal-clo-routing",
      task: "Arbitrate the routing decision only if verifier concerns or low-confidence routing appear in previousRoleOutputs. Otherwise record that arbitration is not required. Return the required arbitration JSON.",
      outputEntryType: "routing.arbitration",
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
