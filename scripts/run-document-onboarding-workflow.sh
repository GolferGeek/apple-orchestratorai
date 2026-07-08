#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${ROOT_DIR}/.runtime/apple-local-state}"
RUN_ID="${RUN_ID:-run-document-onboarding-$(date -u +%Y%m%dT%H%M%SZ)}"
ENVELOPE_FILE="${STATE_DIR}/display-envelopes/${RUN_ID}.json"
RUN_FILE="${STATE_DIR}/runs/${RUN_ID}.json"
MODEL="${MODEL:-qwen3.6:35b-a3b-nvfp4}"

SMOKE_OUTPUT_FILE="${ENVELOPE_FILE}" MODEL="${MODEL}" "${ROOT_DIR}/scripts/run-document-onboarding-fixture.sh"

python3 - "${ENVELOPE_FILE}" "${RUN_FILE}" "${RUN_ID}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

envelope_path, run_path, run_id = sys.argv[1:4]
envelope = json.loads(Path(envelope_path).read_text())
now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

run = {
    "id": run_id,
    "workflowId": envelope["workflowId"],
    "workflowName": "Document Onboarding",
    "status": envelope["status"],
    "profileId": "legal-dev",
    "startedAt": now,
    "completedAt": now,
    "client": envelope["client"],
    "matter": envelope["matter"],
    "stages": envelope["stages"],
    "humanReview": {
        "id": f"human-review-{run_id}",
        "status": "approved",
        "title": "Attorney Review",
        "summary": "Local demo mode approved the synthesized findings.",
        "segments": [
            {
                "id": "document-onboarding-summary",
                "label": "Onboarding Summary",
                "status": "approved",
                "decision": "approve",
                "summary": envelope["markdownSummary"][:220],
            }
        ],
    },
    "outputs": [
        {
            "id": item.get("id", f"output-{index + 1}"),
            "type": item["type"],
            "title": item["title"],
            "content": item["content"],
        }
        for index, item in enumerate(envelope["outputs"])
    ],
}

path = Path(run_path)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(run, indent=2) + "\n")
print(f"wrote-run-record: {path}")
PY
