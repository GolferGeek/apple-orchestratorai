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

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EXECUTION_PLAN = ROOT / "workflows/legal/document-onboarding.execution-plan.json"
OUTPUT_TYPES = {
    "outputs.documentsMetadata": ("documentsMetadata", "json"),
    "outputs.routingDecision": ("routingDecision", "json"),
    "outputs.specialistOutputs": ("specialistOutputs", "json"),
    "outputs.synthesis": ("synthesis", "json"),
    "outputs.nextWorkflowRecommendations": ("nextWorkflowRecommendations", "json"),
    "outputs.reviewPayload": ("reviewPayload", "json"),
    "outputs.response": ("response", "markdown"),
    "outputs.document-onboarding-report": ("document-onboarding-report", "markdown"),
}


def now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load(path):
    return json.loads(Path(path).read_text())


def execution_stage_details(plan_file=DEFAULT_EXECUTION_PLAN):
    plan = load(plan_file)
    details = {}
    for stage in plan["stages"]:
        required_units = [unit for unit in stage["workUnits"] if not unit.get("optional")]
        primary = required_units[-1] if required_units else stage["workUnits"][-1]
        output_ref = next((item for item in reversed(primary.get("outputs", [])) if item.startswith("outputs.")), primary["outputs"][-1])
        output_id, output_type = OUTPUT_TYPES.get(output_ref, (output_ref.split(".")[-1], "json"))
        details[stage["id"]] = {
            "graphId": stage["graphId"],
            "subgraphId": stage.get("subgraphId"),
            "workUnitId": primary["id"],
            "skillId": primary["skillId"],
            "outputId": output_id,
            "outputType": output_type,
        }
    return details


STAGE_DETAILS = execution_stage_details()


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


def stage_payload(stage_id, run_id=None, workflow_id=None, status=None, summary=None, message=None, result_file=None):
    detail = STAGE_DETAILS[stage_id]
    payload = {
        "stageId": stage_id,
        "graphId": detail["graphId"],
        "subgraphId": detail["subgraphId"],
        "workUnitId": detail["workUnitId"],
        "skillId": detail["skillId"],
    }
    if run_id:
        payload["runId"] = run_id
    if workflow_id:
        payload["workflowId"] = workflow_id
    if status:
        payload["status"] = status
    if summary:
        payload["summary"] = summary
    if message:
        payload["message"] = message
    payload["outputs"] = [
        {
            "id": detail["outputId"],
            "type": detail["outputType"],
            "uri": f"apple-local://runs/{run_id}/stage-results/{stage_id}.json" if run_id and result_file else None,
            "title": STAGE_NAMES[stage_id],
        }
    ]
    return payload


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
    document_count = len(fixture.get("fileSystemDocuments", {}).get("filePaths", []))
    append_event(
        events_file,
        "workflow.started",
        runId=run_id,
        workflowId=fixture["workflowId"],
        status="running",
        summary="Document onboarding started.",
        message=f"Resolving and reviewing {document_count} matter documents.",
        progress={"current": 0, "total": len(STAGE_NAMES), "unit": "stages"},
        metrics={"document_count": document_count},
    )


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
    completed_count = sum(1 for stage in run["stages"] if stage["status"] == "completed")
    detail = STAGE_DETAILS[stage_id]

    append_event(
        events_file,
        "work_unit.completed",
        **stage_payload(
            stage_id,
            run_id=run["id"],
            workflow_id=run["workflowId"],
            status=result.get("status", "completed"),
            summary=result.get("summary", ""),
            message=result.get("output", ""),
            result_file=result_file,
        ),
        progress={"current": completed_count, "total": len(run["stages"]), "unit": "stages"},
        metrics={
            "completed_stage_count": completed_count,
            "remaining_stage_count": len(run["stages"]) - completed_count,
        },
        raw={"stageResult": result},
        rawHermesRunId=result.get("_rawHermesRunId", ""),
    )

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
        append_event(
            events_file,
            "human_review.completed",
            runId=run["id"],
            workflowId=run["workflowId"],
            stageId=stage_id,
            graphId=detail["graphId"],
            subgraphId=detail["subgraphId"],
            workUnitId=detail["workUnitId"],
            skillId=detail["skillId"],
            reviewId=run["humanReview"]["id"],
            status="approved",
            summary=run["humanReview"]["summary"],
            message="Demo attorney review accepted all segments.",
        )

    save(run_file, run)
    append_event(
        events_file,
        "stage.completed",
        **stage_payload(
            stage_id,
            run_id=run["id"],
            workflow_id=run["workflowId"],
            status=result.get("status", "completed"),
            summary=result.get("summary", ""),
            message=result.get("output", ""),
            result_file=result_file,
        ),
        progress={"current": completed_count, "total": len(run["stages"]), "unit": "stages"},
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
    append_event(
        events_file,
        "workflow.completed",
        runId=run["id"],
        workflowId=run["workflowId"],
        status="completed",
        summary=summary,
        message="Final document onboarding output packet is ready.",
        progress={"current": len(run["stages"]), "total": len(run["stages"]), "unit": "stages"},
        metrics={
            "stage_count": len(run["stages"]),
            "output_count": len(run["outputs"]),
        },
        outputs=[
            {
                "id": "output-summary",
                "type": "markdown",
                "uri": f"apple-local://runs/{run['id']}/outputs/output-summary.md",
                "title": "Document Onboarding Complete",
            }
        ],
    )


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
