#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="${ROOT_DIR}/test-fixtures/legal/document-onboarding/acme-renewal/input.json"
WORKFLOW="${ROOT_DIR}/workflows/legal/document-onboarding.workflow.json"
MODEL="${MODEL:-qwen3.6:35b-a3b-nvfp4}"

if [[ ! -f "${FIXTURE}" ]]; then
  echo "Missing fixture: ${FIXTURE}" >&2
  exit 1
fi

prompt="$(python3 - "${WORKFLOW}" "${FIXTURE}" <<'PY'
import json
import sys

workflow_path, fixture_path = sys.argv[1:3]
workflow = json.load(open(workflow_path))
fixture = json.load(open(fixture_path))

print(
    "Run the Apple Orchestrator AI legal document onboarding workflow in local-only demo mode.\n"
    "Use the workflow definition and fixture below. Return ONLY valid compact JSON. "
    "Do not include markdown fences, commentary, planning text, or tool-call prose. "
    "Keep every summary string under 240 characters. Keep markdownSummary under 900 characters. "
    "Each output content must be under 900 characters. "
    "The JSON object must have exactly this display envelope shape:\n"
    "{"
    "\"status\":\"completed|needs_human_review|failed\","
    "\"workflowId\":\"string\","
    "\"client\":{\"id\":\"string\",\"name\":\"string\"},"
    "\"matter\":{\"id\":\"string\",\"name\":\"string\"},"
    "\"stages\":[{\"id\":\"string\",\"name\":\"string\",\"status\":\"completed|needs_human_review|failed\",\"summary\":\"string\"}],"
    "\"humanReviewRequired\":false,"
    "\"markdownSummary\":\"string\","
    "\"outputs\":[{\"type\":\"markdown|json|file\",\"title\":\"string\",\"content\":\"string\"}]"
    "}\n\n"
    "Workflow definition:\n"
    + json.dumps(workflow, indent=2)
    + "\n\nFixture:\n"
    + json.dumps(fixture, indent=2)
)
PY
)"

SMOKE_EXPECT_JSON=1 SMOKE_POLL_COUNT=300 SMOKE_PROMPT="${prompt}" "${ROOT_DIR}/scripts/smoke-hermes-ollama-run.sh" "${MODEL}"
