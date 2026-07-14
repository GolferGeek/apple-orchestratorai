#!/usr/bin/env python3
import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


def iso_mtime(path: Path) -> str:
    return datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat().replace("+00:00", "Z")


def slug_from_path(path: Path) -> str:
    return path.stem


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def markdown_title(text: str, fallback: str) -> str:
    for line in text.splitlines():
        match = re.match(r"^#\s+(?:Effort:\s*)?(.+?)\s*$", line)
        if match:
            return match.group(1)
    return fallback.replace("-", " ").title()


def markdown_summary(text: str) -> str:
    in_goal = False
    lines = []
    for line in text.splitlines():
        if line.strip() == "## Goal":
            in_goal = True
            continue
        if in_goal and line.startswith("## "):
            break
        if in_goal and line.strip():
            lines.append(line.strip())
    return " ".join(lines)


def load_apps(repo_root: Path) -> dict:
    with (repo_root / "config/apps.json").open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    return {app["id"]: app for app in data.get("apps", [])}


def rel(path: Path, repo_root: Path) -> str:
    try:
        return str(path.relative_to(repo_root))
    except ValueError:
        return str(path)


def render_inbox(efforts_root: Path, repo_root: Path) -> list[dict]:
    inbox = efforts_root / "inbox"
    items = []
    if not inbox.exists():
        return items
    for path in sorted(inbox.glob("*.md")):
        text = read_text(path)
        items.append(
            {
                "id": slug_from_path(path),
                "title": markdown_title(text, slug_from_path(path)),
                "path": rel(path, repo_root),
                "updatedAt": iso_mtime(path),
                "summary": markdown_summary(text),
            }
        )
    return items


def load_questions(path: Path) -> tuple[int, bool]:
    if not path.exists():
        return 0, False
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return 0, False
    questions = data.get("questions", [])
    if not isinstance(questions, list):
        return 0, False
    blocking = any(bool(q.get("blocking")) and q.get("status", "open") == "open" for q in questions if isinstance(q, dict))
    return len(questions), blocking


def artifact_count(path: Path) -> int:
    if not path.exists():
        return 0
    return sum(1 for child in path.iterdir() if child.name != ".gitkeep")


def result_summary(path: Path) -> str:
    text = read_text(path).strip()
    if not text or text == "# Result\n\nNo result yet.":
        return ""
    lines = [line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")]
    return " ".join(lines[:3])


def render_efforts(efforts_root: Path, repo_root: Path, state: str) -> list[dict]:
    state_root = efforts_root / state
    items = []
    if not state_root.exists():
        return items
    for effort_dir in sorted(path for path in state_root.iterdir() if path.is_dir()):
        effort_json = effort_dir / "effort.json"
        if not effort_json.exists():
            continue
        with effort_json.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        intention_text = read_text(effort_dir / "intention.md")
        question_count, has_blocking = load_questions(effort_dir / "questions.json")
        updated = max((child.stat().st_mtime for child in effort_dir.iterdir()), default=effort_dir.stat().st_mtime)
        items.append(
            {
                "id": data.get("id", effort_dir.name),
                "title": markdown_title(intention_text, data.get("id", effort_dir.name)),
                "status": state,
                "path": rel(effort_dir, repo_root),
                "profileId": data.get("profileId", "coder"),
                "turn": data.get(
                    "turn",
                    {
                        "owner": "codex",
                        "state": "ready",
                        "reason": "No turn state was recorded.",
                        "since": "",
                        "questionIds": [],
                    },
                ),
                "questionCount": question_count,
                "hasBlockingQuestions": has_blocking,
                "resultSummary": result_summary(effort_dir / "result.md"),
                "artifactCount": artifact_count(effort_dir / "artifacts"),
                "updatedAt": datetime.fromtimestamp(updated, timezone.utc).isoformat().replace("+00:00", "Z"),
            }
        )
    return items


def main() -> int:
    parser = argparse.ArgumentParser(description="Render the coder efforts profile surface as JSON.")
    parser.add_argument("--app-id", default="apple-orchestratorai")
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    apps = load_apps(repo_root)
    if args.app_id not in apps:
        raise SystemExit(f"unknown app id: {args.app_id}")

    efforts_root = (repo_root / apps[args.app_id]["effortsRoot"]).resolve()
    payload = {
        "schemaVersion": "0.1.0",
        "profileId": "coder",
        "surfaceId": "efforts",
        "appId": args.app_id,
        "generatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "sections": {
            "inbox": render_inbox(efforts_root, repo_root),
            "current": render_efforts(efforts_root, repo_root, "current"),
            "future": render_efforts(efforts_root, repo_root, "future"),
            "archive": render_efforts(efforts_root, repo_root, "archive"),
        },
    }
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
