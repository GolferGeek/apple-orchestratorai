#!/usr/bin/env python3
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


STAGE_NAMES = {
    "metadata": "Metadata",
    "classify": "Classify",
    "specialists": "Specialists",
    "synthesis": "Synthesis",
    "hitl_review": "Human Review",
    "report": "Report",
}


def now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load(path):
    return json.loads(Path(path).read_text())


def save(path, value):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, indent=2) + "\n")


def append_event(events_file, event_type, **payload):
    target = Path(events_file)
    target.parent.mkdir(parents=True, exist_ok=True)
    event = {"timestamp": now(), "type": event_type, **payload}
    with target.open("a") as handle:
        handle.write(json.dumps(event, separators=(",", ":")) + "\n")


def init_run(run_file, events_file, run_id, fixture_file):
    fixture = load(fixture_file)
    run = {
        "id": run_id,
        "workflowId": fixture["workflowId"],
        "workflowName": "Document Onboarding",
        "status": "running",
        "profileId": fixture["profileId"],
        "startedAt": now(),
        "completedAt": None,
        "client": {
            "id": fixture["client"]["id"],
            "name": fixture["client"]["name"],
        },
        "matter": {
            "id": fixture["matter"]["id"],
            "name": fixture["matter"]["name"],
        },
        "stages": [
            {
                "id": stage_id,
                "name": STAGE_NAMES[stage_id],
                "status": "defined",
                "summary": "Waiting to run.",
            }
            for stage_id in STAGE_NAMES
        ],
        "humanReview": None,
        "outputs": [],
    }
    save(run_file, run)
    append_event(events_file, "workflow.started", runId=run_id, workflowId=fixture["workflowId"])


def mark_stage(run_file, events_file, stage_id, result_file):
    run = load(run_file)
    result = load(result_file)
    for stage in run["stages"]:
        if stage["id"] == stage_id:
            stage["name"] = result.get("name", stage["name"])
            stage["status"] = result.get("status", "completed")
            stage["summary"] = result.get("summary", "")
            break
    else:
        raise SystemExit(f"Unknown stage id: {stage_id}")

    run["status"] = "waiting_for_human" if stage_id == "hitl_review" else "running"

    if stage_id == "hitl_review":
        run["humanReview"] = {
            "id": f"human-review-{run['id']}",
            "status": "approved",
            "title": "Attorney Review",
            "summary": result.get("summary", "Human review completed."),
            "segments": [
                {
                    "id": "contract",
                    "label": "Contract Findings",
                    "status": "approved",
                    "decision": "approve",
                    "summary": "Contract findings accepted for demo run.",
                },
                {
                    "id": "privacy",
                    "label": "Privacy Findings",
                    "status": "approved",
                    "decision": "approve",
                    "summary": "Privacy findings accepted for demo run.",
                },
            ],
        }
        append_event(events_file, "human_review.completed", runId=run["id"], reviewId=run["humanReview"]["id"])

    save(run_file, run)
    append_event(
        events_file,
        "stage.completed",
        runId=run["id"],
        stageId=stage_id,
        rawHermesRunId=result.get("_rawHermesRunId", ""),
    )


def finalize(run_file, events_file, envelope_file):
    run = load(run_file)
    run["status"] = "completed"
    run["completedAt"] = now()
    summary = "Document onboarding completed for " + run["client"]["name"] + "."
    run["outputs"] = [
        {
            "id": "output-summary",
            "type": "markdown",
            "title": "Document Onboarding Complete",
            "content": summary,
        }
    ]
    save(run_file, run)

    envelope = {
        "status": "completed",
        "workflowId": run["workflowId"],
        "client": run["client"],
        "matter": run["matter"],
        "stages": run["stages"],
        "humanReviewRequired": False,
        "markdownSummary": summary,
        "outputs": run["outputs"],
    }
    save(envelope_file, envelope)
    append_event(events_file, "workflow.completed", runId=run["id"])


def main():
    command = sys.argv[1]
    if command == "init":
        _, _, run_file, events_file, run_id, fixture_file = sys.argv
        init_run(run_file, events_file, run_id, fixture_file)
    elif command == "stage":
        _, _, run_file, events_file, stage_id, result_file = sys.argv
        mark_stage(run_file, events_file, stage_id, result_file)
    elif command == "finalize":
        _, _, run_file, events_file, envelope_file = sys.argv
        finalize(run_file, events_file, envelope_file)
    else:
        raise SystemExit(f"Unknown command: {command}")


if __name__ == "__main__":
    main()
