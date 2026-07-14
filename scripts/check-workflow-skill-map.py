#!/usr/bin/env python3
import base64
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_AGENT = ROOT / "workflows/legal/document-onboarding.workflow-agent.md"


def load_json(path):
    return json.loads(path.read_text())


def decode(value):
    value = value.replace("_", "=")
    value += "=" * ((4 - len(value) % 4) % 4)
    return base64.b64decode(value).decode("utf-8")


def skill_ids():
    ids = {}
    aliases = {}
    for path in ROOT.glob("skills/**/*.skill.json"):
        data = load_json(path)
        if data.get("id"):
            ids[data["id"]] = path
        for alias in data.get("aliases", []):
            aliases[alias] = path
    return ids, aliases


def agent_work_units(path):
    stage_stack = []
    lines = path.read_text().splitlines()
    for index, line in enumerate(lines):
        if "<!-- ao-node " not in line:
            continue
        values = dict(part.split("=", 1) for part in line.strip()[len("<!-- ao-node "):-len(" -->")].split(" "))
        kind = values["kind"]
        node_id = decode(values["id"])
        detail = decode(values["detail"])
        depth = (len(lines[index - 1]) - len(lines[index - 1].lstrip(" "))) // 2
        while stage_stack and stage_stack[-1][0] >= depth:
            stage_stack.pop()
        if kind == "phase":
            stage_stack.append((depth, node_id))
        elif kind == "work_unit":
            match = re.search(r"Uses ([^ ]+)", detail)
            if match:
                yield stage_stack[-1][1] if stage_stack else "unknown", node_id, match.group(1).rstrip(".")


def main():
    agent_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_AGENT
    ids, aliases = skill_ids()
    missing = []
    for stage_id, work_unit_id, skill_id in agent_work_units(agent_path):
        if skill_id not in ids and skill_id not in aliases:
            missing.append((stage_id, work_unit_id, skill_id))

    if missing:
        for stage_id, work_unit_id, skill_id in missing:
            print(f"missing-skill stage={stage_id} workUnit={work_unit_id} skill={skill_id}")
        raise SystemExit(1)
    print(f"skill-map-ok {agent_path}")


if __name__ == "__main__":
    main()
