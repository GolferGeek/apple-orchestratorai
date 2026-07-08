#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_json(path):
    return json.loads(path.read_text())


def skill_ids():
    ids = {}
    aliases = {}
    for path in ROOT.glob("skills/**/*.skill.json"):
        data = load_json(path)
        skill_id = data.get("id")
        if skill_id:
            ids[skill_id] = path
        for alias in data.get("aliases", []):
            aliases[alias] = path
    return ids, aliases


def plan_skill_ids(plan):
    for stage in plan.get("stages", []):
        for work_unit in stage.get("workUnits", []):
            yield stage["id"], work_unit["id"], work_unit["skillId"]


def validate_stage_order(plan):
    source_workflow = plan.get("sourceWorkflow")
    if not source_workflow:
        return []

    workflow_path = ROOT / source_workflow
    workflow = load_json(workflow_path)
    expected = workflow["runtime"]["observability"]["presentationStages"]
    actual = [stage["id"] for stage in plan.get("stages", [])]
    if actual != expected:
        return [f"stage-order-mismatch expected={expected} actual={actual}"]
    return []


def main():
    plan_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "workflows/legal/document-onboarding.execution-plan.json"
    plan = load_json(plan_path)
    ids, aliases = skill_ids()
    missing = []
    errors = validate_stage_order(plan)

    for stage_id, work_unit_id, skill_id in plan_skill_ids(plan):
        if skill_id not in ids and skill_id not in aliases:
            missing.append((stage_id, work_unit_id, skill_id))

    if missing:
        for stage_id, work_unit_id, skill_id in missing:
            print(f"missing-skill stage={stage_id} workUnit={work_unit_id} skill={skill_id}")
        raise SystemExit(1)

    if errors:
        for error in errors:
            print(error)
        raise SystemExit(1)

    print(f"skill-map-ok {plan_path}")


if __name__ == "__main__":
    main()
