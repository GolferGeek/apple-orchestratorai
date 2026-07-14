#!/usr/bin/env python3
import argparse
import importlib.util
import json
import os
import selectors
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WRAPPER_PATH = ROOT / "scripts/wrap-pi-events.py"
DEFAULT_STATE_DIR = Path(os.environ.get(
    "APPLE_ORCHESTRATOR_STATE_DIR",
    Path.home() / "Library/Application Support/Apple Orchestrator AI",
))
DEFAULT_PI_BIN = ROOT / ".runtime/pi/packages/coding-agent/dist/cli.js"


def load_wrapper():
    spec = importlib.util.spec_from_file_location("wrap_pi_events", WRAPPER_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WRAPPER = load_wrapper()


def now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def env_from_pi_env():
    env_file = ROOT / ".runtime/pi-env.sh"
    values = {}
    if not env_file.exists():
        return values
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line.startswith("export ") or "=" not in line:
            continue
        key, value = line[len("export ") :].split("=", 1)
        value = value.strip().strip('"')
        value = value.replace("${PI_TELEMETRY:-0}", os.environ.get("PI_TELEMETRY", "0"))
        values[key] = value
    return values


def compact_none(payload):
    return {key: value for key, value in payload.items() if value is not None}


def wrapper_args(args, command_id=None):
    return argparse.Namespace(
        run_id=args.run_id,
        workflow_id=args.workflow_id,
        stage_id=args.stage_id,
        graph_id=args.graph_id,
        subgraph_id=args.subgraph_id,
        work_unit_id=args.work_unit_id,
        skill_id=args.skill_id,
        team_id=args.team_id,
        role_id=args.role_id,
        session_id=args.session_id,
        command_id=command_id,
    )


def write_event(events_file, raw_file, raw, args, command_id=None):
    raw_file.parent.mkdir(parents=True, exist_ok=True)
    events_file.parent.mkdir(parents=True, exist_ok=True)
    wrapped = WRAPPER.wrap(raw, wrapper_args(args, command_id=command_id))
    event = WRAPPER.to_workflow_event(wrapped)
    with raw_file.open("a") as handle:
        handle.write(json.dumps(raw, separators=(",", ":")) + "\n")
    with events_file.open("a") as handle:
        handle.write(json.dumps(event, separators=(",", ":")) + "\n")
    return event


def mock_events(args, events_file, raw_file):
    command_id = args.command_id or f"pi-smoke-{int(time.time())}"
    samples = [
        {"type": "agent_start", "timestamp": now(), "message": "Pi workflow worker started.", "sessionId": args.session_id or "mock-session", "id": command_id},
        {"type": "turn_start", "timestamp": now(), "message": "Planning the requested workflow step.", "sessionId": args.session_id or "mock-session", "id": command_id},
        {"type": "tool_execution_start", "timestamp": now(), "message": "Resolving workflow skill inputs.", "sessionId": args.session_id or "mock-session", "id": command_id},
        {"type": "tool_execution_end", "timestamp": now(), "message": "Workflow skill inputs resolved.", "sessionId": args.session_id or "mock-session", "id": command_id},
        {"type": "agent_end", "timestamp": now(), "message": "Pi workflow worker completed.", "sessionId": args.session_id or "mock-session", "id": command_id},
    ]
    for sample in samples:
        write_event(events_file, raw_file, sample, args, command_id=command_id)
    return len(samples)


def pi_command(args, env):
    pi_bin = Path(args.pi_bin or env.get("PI_BIN") or DEFAULT_PI_BIN)
    node_bin = args.node_bin or env.get("PI_NODE_BIN") or "node"
    model = args.model
    command = [
        node_bin,
        str(pi_bin),
        "--mode",
        "rpc",
        "--provider",
        args.provider,
        "--model",
        model,
        "--api-key",
        args.api_key,
        "--no-session",
    ]
    for extension in args.extension:
        command.extend(["--extension", extension])
    for skill in args.skill:
        command.extend(["--skill", skill])
    for prompt_template in args.prompt_template:
        command.extend(["--prompt-template", prompt_template])
    for system_prompt in args.append_system_prompt:
        command.extend(["--append-system-prompt", system_prompt])
    if args.no_tools:
        command.append("--no-tools")
    if args.no_builtin_tools:
        command.append("--no-builtin-tools")
    if args.tools:
        command.extend(["--tools", args.tools])
    if args.no_extensions:
        command.append("--no-extensions")
    if args.no_skills:
        command.append("--no-skills")
    if args.no_prompt_templates:
        command.append("--no-prompt-templates")
    return command, pi_bin


def run_pi(args, events_file, raw_file):
    env = os.environ.copy()
    env.update(env_from_pi_env())
    command, pi_bin = pi_command(args, env)
    if not pi_bin.exists():
        raise SystemExit(f"Pi is not built yet: {pi_bin}. Run scripts/bootstrap-pi.sh, or use --mock.")

    command_id = args.command_id or f"pi-smoke-{int(time.time())}"
    request = compact_none(
        {
            "id": command_id,
            "type": "prompt",
            "message": args.prompt,
        }
    )

    process = subprocess.Popen(
        command,
        cwd=str(ROOT),
        env=env,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    assert process.stdin is not None
    process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
    process.stdin.flush()

    selector = selectors.DefaultSelector()
    assert process.stdout is not None
    assert process.stderr is not None
    selector.register(process.stdout, selectors.EVENT_READ, "stdout")
    selector.register(process.stderr, selectors.EVENT_READ, "stderr")

    event_count = 0
    started = time.time()
    stderr_lines = []
    stop_types = {event_type.strip() for event_type in args.stop_on.split(",") if event_type.strip()}
    while time.time() - started < args.timeout_seconds:
        if process.poll() is not None:
            break
        for key, _ in selector.select(timeout=0.25):
            line = key.fileobj.readline()
            if not line:
                continue
            line = line.strip()
            if not line:
                continue
            if key.data == "stderr":
                stderr_lines.append(line)
                continue
            try:
                raw = json.loads(line)
            except json.JSONDecodeError:
                raw = {"type": "runtime.stdout", "timestamp": now(), "message": line}
            event = write_event(events_file, raw_file, raw, args, command_id=command_id)
            event_count += 1
            if stop_types and event["type"] in stop_types:
                process.terminate()
                break
        else:
            continue
        break

    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()

    if process.stdin and not process.stdin.closed:
        process.stdin.close()

    if stderr_lines:
        stderr_path = raw_file.with_suffix(".stderr.log")
        stderr_path.write_text("\n".join(stderr_lines) + "\n")
    return event_count


def main():
    parser = argparse.ArgumentParser(description="Run a Pi RPC event smoke test and persist normalized workflow events.")
    parser.add_argument("--run-id", default=f"run-pi-rpc-smoke-{datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}")
    parser.add_argument("--workflow-id", default="runtime.pi-smoke")
    parser.add_argument("--stage-id", default="runtime")
    parser.add_argument("--graph-id")
    parser.add_argument("--subgraph-id")
    parser.add_argument("--work-unit-id", default="pi.rpc-smoke")
    parser.add_argument("--skill-id", default="runtime.pi-rpc-smoke")
    parser.add_argument("--team-id")
    parser.add_argument("--role-id")
    parser.add_argument("--session-id")
    parser.add_argument("--command-id")
    parser.add_argument("--state-dir", default=str(DEFAULT_STATE_DIR))
    parser.add_argument("--pi-bin")
    parser.add_argument("--node-bin")
    parser.add_argument("--provider", default="ollama")
    parser.add_argument("--model", default=os.environ.get("MODEL", "qwen3.6:35b-mlx"))
    parser.add_argument("--api-key", default="ollama")
    parser.add_argument("--prompt", default="Say exactly: Pi RPC event smoke complete.")
    parser.add_argument("--timeout-seconds", type=float, default=20.0)
    parser.add_argument("--mock", action="store_true")
    parser.add_argument("--extension", action="append", default=[])
    parser.add_argument("--skill", action="append", default=[])
    parser.add_argument("--prompt-template", action="append", default=[])
    parser.add_argument("--append-system-prompt", action="append", default=[])
    parser.add_argument("--tools")
    parser.add_argument("--no-tools", action="store_true")
    parser.add_argument("--no-builtin-tools", action="store_true")
    parser.add_argument("--no-extensions", action="store_true")
    parser.add_argument("--no-skills", action="store_true")
    parser.add_argument("--no-prompt-templates", action="store_true")
    parser.add_argument("--stop-on", default="work_unit.completed,workflow.completed,runtime.error")
    args = parser.parse_args()

    state_dir = Path(args.state_dir)
    events_file = state_dir / "events" / f"{args.run_id}.jsonl"
    raw_file = state_dir / "raw-pi-events" / f"{args.run_id}.jsonl"

    if args.mock:
        count = mock_events(args, events_file, raw_file)
    else:
        count = run_pi(args, events_file, raw_file)

    print(f"wrote-events: {events_file}")
    print(f"wrote-raw-pi-events: {raw_file}")
    print(f"event-count: {count}")
    if count == 0:
        raise SystemExit("Pi RPC smoke produced no events")


if __name__ == "__main__":
    main()
