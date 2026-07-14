#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json"
WORKFLOW_AGENT="${ROOT_DIR}/workflows/legal/document-onboarding.workflow-agent.md"
MODEL="${MODEL:-qwen3.6:35b-mlx}"

if [[ ! -f "${FIXTURE}" ]]; then
  echo "Missing fixture: ${FIXTURE}" >&2
  exit 1
fi

prompt="$(python3 - "${WORKFLOW_AGENT}" "${FIXTURE}" <<'PY'
import json
import sys

agent_path, fixture_path = sys.argv[1:3]
fixture = json.load(open(fixture_path))
workflow_summary = {
    "source": agent_path,
    "name": "Document Onboarding",
    "stages": ["metadata", "classify", "specialists", "synthesis", "hitl_review", "report"],
    "defaultLocalModel": "qwen3.6:35b-mlx",
}
fixture_summary = {
    "workflowId": fixture["workflowId"],
    "profileId": fixture["profileId"],
    "classification": fixture["classification"],
    "client": fixture["client"],
    "matter": fixture["matter"],
    "fileSystemDocuments": fixture["fileSystemDocuments"],
    "reviewInstructions": fixture["reviewInstructions"],
}

print(
    "Produce a UI display envelope for one local-only legal document onboarding demo run.\n"
    "Return ONLY one-line valid JSON. No markdown fences. No commentary. No trailing text. "
    "Use only facts from the fixture. The client is Acme Robotics LLC and the vendor is Northwind Supply Inc. "
    "Do not introduce Acme Corp, Beta LLC, Delaware law, or a $50K fee unless those facts appear in the fixture. "
    "Keep every stage summary under 80 characters. Keep markdownSummary under 300 characters. "
    "The outputs array must contain exactly one item. Its content must be plain text under 180 characters. "
    "Do not put JSON, braces, brackets, or escaped quotes inside any string value. "
    "Every outputs item must have type \"markdown\" and its content must be a simple string, not an object or array. "
    "Use exactly these six stage ids in order: metadata, classify, specialists, synthesis, hitl_review, report. "
    "The JSON object must have this shape:\n"
    "{"
    "\"status\":\"completed\","
    "\"workflowId\":\"string\","
    "\"client\":{\"id\":\"string\",\"name\":\"string\"},"
    "\"matter\":{\"id\":\"string\",\"name\":\"string\"},"
    "\"stages\":[{\"id\":\"string\",\"name\":\"string\",\"status\":\"completed\",\"summary\":\"string\"}],"
    "\"humanReviewRequired\":false,"
    "\"markdownSummary\":\"string\","
    "\"outputs\":[{\"type\":\"markdown\",\"title\":\"Document Onboarding Complete\",\"content\":\"Completed local demo run for Acme Robotics LLC.\"}]"
    "}\n\n"
    "Workflow summary:\n"
    + json.dumps(workflow_summary, separators=(",", ":"))
    + "\n\nFixture summary:\n"
    + json.dumps(fixture_summary, separators=(",", ":"))
)
PY
)"

SMOKE_EXPECT_JSON=1 SMOKE_POLL_COUNT=300 SMOKE_PROMPT="${prompt}" "${ROOT_DIR}/scripts/smoke-hermes-ollama-run.sh" "${MODEL}"
