#!/usr/bin/env python3
import argparse
import json
import sys
from datetime import datetime, timezone


EVENT_MAP = {
    "agent_start": "work_unit.started",
    "agent_end": "work_unit.completed",
    "turn_start": "runtime.turn.started",
    "turn_end": "runtime.turn.completed",
    "message_start": "runtime.message.started",
    "message_update": "runtime.message.updated",
    "message_end": "runtime.message.completed",
    "tool_execution_start": "tool.started",
    "tool_execution_update": "tool.updated",
    "tool_execution_end": "tool.completed",
    "queue_update": "runtime.queue.updated",
    "compaction_start": "runtime.compaction.started",
    "compaction_end": "runtime.compaction.completed",
    "auto_retry_start": "runtime.retry.started",
    "auto_retry_end": "runtime.retry.completed",
    "extension_error": "runtime.error",
    "extension_ui_request": "runtime.ui.requested",
}


TERMINAL_EVENTS = {
    "agent_end",
    "turn_end",
    "message_end",
    "tool_execution_end",
    "compaction_end",
    "auto_retry_end",
}


def now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def read_type(raw):
    for key in ("type", "event", "name"):
        value = raw.get(key)
        if isinstance(value, str) and value:
            return value
    return "unknown"


def read_timestamp(raw):
    for key in ("timestamp", "created_at", "createdAt", "time"):
        value = raw.get(key)
        if isinstance(value, str) and value:
            return value
    return now()


def first_string(raw, *keys):
    for key in keys:
        value = raw.get(key)
        if isinstance(value, str) and value:
            return value
    return None


def read_message(raw):
    for key in ("message", "summary", "text", "content", "error"):
        value = raw.get(key)
        if isinstance(value, str) and value:
            return value
    data = raw.get("data")
    if isinstance(data, dict):
        return first_string(data, "message", "summary", "text", "content", "error")
    return None


def message_error(raw):
    message = raw.get("message")
    if isinstance(message, dict):
        error = first_string(message, "errorMessage", "error")
        if error:
            return error
        if message.get("stopReason") == "error":
            return "Pi model turn ended with an error."
    messages = raw.get("messages")
    if isinstance(messages, list):
        for item in reversed(messages):
            if isinstance(item, dict):
                error = first_string(item, "errorMessage", "error")
                if error:
                    return error
                if item.get("stopReason") == "error":
                    return "Pi model turn ended with an error."
    return None


def raw_has_error(raw):
    if raw.get("success") is False:
        return True
    if raw.get("isError") is True:
        return True
    return message_error(raw) is not None


def workflow_event_type(pi_event_type, args):
    raw_success = getattr(args, "_current_success", None)
    if raw_success is False or getattr(args, "_current_has_error", False):
        return "runtime.error"
    if pi_event_type == "agent_start" and not args.work_unit_id:
        return "workflow.started"
    if pi_event_type == "agent_end" and not args.work_unit_id:
        return "workflow.completed"
    if pi_event_type == "extension_ui_request":
        raw_method = getattr(args, "_current_ui_method", "")
        if raw_method in {"confirm", "select", "input", "editor"}:
            return "human_review.requested"
    return EVENT_MAP.get(pi_event_type, f"runtime.pi.{pi_event_type}")


def status_for(pi_event_type):
    if pi_event_type == "response":
        return "updated"
    if pi_event_type.endswith("_start"):
        return "running"
    if pi_event_type in TERMINAL_EVENTS:
        return "completed"
    if pi_event_type == "extension_error":
        return "failed"
    if pi_event_type == "extension_ui_request":
        return "waiting_for_human"
    return "updated"


def compact_none(payload):
    return {key: value for key, value in payload.items() if value is not None}


def wrap(raw, args):
    pi_event_type = read_type(raw)
    data = raw.get("data") if isinstance(raw.get("data"), dict) else {}
    ui_method = first_string(raw, "method") or first_string(data, "method")
    setattr(args, "_current_success", raw.get("success") if isinstance(raw.get("success"), bool) else None)
    setattr(args, "_current_has_error", raw_has_error(raw))
    setattr(args, "_current_ui_method", ui_method or "")
    mapped_type = workflow_event_type(pi_event_type, args)
    normalized_message = read_message(raw) or message_error(raw)
    wrapped = compact_none(
        {
            "schemaVersion": "pi-runtime-event.v0",
            "timestamp": read_timestamp(raw),
            "runtime": "pi",
            "runId": args.run_id,
            "workflowId": args.workflow_id,
            "stageId": args.stage_id,
            "graphId": args.graph_id,
            "subgraphId": args.subgraph_id,
            "workUnitId": args.work_unit_id,
            "skillId": args.skill_id,
            "teamId": args.team_id,
            "roleId": args.role_id,
            "sessionId": first_string(raw, "sessionId", "session_id") or args.session_id,
            "commandId": first_string(raw, "id", "commandId", "command_id") or args.command_id,
            "piEventType": pi_event_type,
            "workflowEventType": mapped_type,
            "status": "failed" if mapped_type == "runtime.error" else status_for(pi_event_type),
            "summary": normalized_message,
            "message": normalized_message,
            "raw": raw,
        }
    )
    return wrapped


def to_workflow_event(wrapped):
    event = {
        "timestamp": wrapped["timestamp"],
        "type": wrapped["workflowEventType"],
        "runId": wrapped["runId"],
        "workflowId": wrapped.get("workflowId"),
        "stageId": wrapped.get("stageId"),
        "graphId": wrapped.get("graphId"),
        "subgraphId": wrapped.get("subgraphId"),
        "workUnitId": wrapped.get("workUnitId"),
        "skillId": wrapped.get("skillId"),
        "teamId": wrapped.get("teamId"),
        "roleId": wrapped.get("roleId"),
        "status": wrapped.get("status"),
        "summary": wrapped.get("summary"),
        "message": wrapped.get("message"),
        "rawPiSessionId": wrapped.get("sessionId"),
        "rawPiCommandId": wrapped.get("commandId"),
        "raw": wrapped,
    }
    return compact_none(event)


def main():
    parser = argparse.ArgumentParser(description="Wrap Pi JSONL runtime events into Apple Orchestrator workflow events.")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--workflow-id")
    parser.add_argument("--stage-id")
    parser.add_argument("--graph-id")
    parser.add_argument("--subgraph-id")
    parser.add_argument("--work-unit-id")
    parser.add_argument("--skill-id")
    parser.add_argument("--team-id")
    parser.add_argument("--role-id")
    parser.add_argument("--session-id")
    parser.add_argument("--command-id")
    parser.add_argument("--emit", choices=("workflow", "pi"), default="workflow")
    args = parser.parse_args()

    for line_number, line in enumerate(sys.stdin, start=1):
        line = line.strip()
        if not line:
            continue
        try:
            raw = json.loads(line)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"line {line_number}: invalid JSON: {exc}") from exc
        if not isinstance(raw, dict):
            raise SystemExit(f"line {line_number}: expected JSON object")
        wrapped = wrap(raw, args)
        output = wrapped if args.emit == "pi" else to_workflow_event(wrapped)
        print(json.dumps(output, separators=(",", ":")), flush=True)


if __name__ == "__main__":
    main()
