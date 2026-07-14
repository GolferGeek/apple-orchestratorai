#!/usr/bin/env node

// One-time migration utility for legacy Apple Orchestrator workflow JSON.
// The generated Markdown agent is the source of truth consumed by the app.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const workflowPath = process.argv[2] ?? path.join(root, "workflows/legal/document-onboarding.workflow.json");
const planPath = process.argv[3] ?? path.join(root, "workflows/legal/document-onboarding.execution-plan.json");
const teamPath = process.argv[4] ?? path.join(root, "workflows/legal/document-onboarding.work-teams.json");

const workflow = JSON.parse(fs.readFileSync(workflowPath, "utf8"));
const plan = JSON.parse(fs.readFileSync(planPath, "utf8"));
const teams = JSON.parse(fs.readFileSync(teamPath, "utf8"));
const teamById = new Map(teams.teams.map((team) => [team.id, team]));
const encode = (value) => Buffer.from(String(value), "utf8").toString("base64").replaceAll("=", "_");
const lineFor = (node) => `<!-- ao-node kind=${node.kind} id=${encode(node.id)} name=${encode(node.name)} detail=${encode(node.detail ?? "")} model=${encode(node.model ?? "")} required=${node.required === false ? "0" : "1"} events=${encode((node.events ?? []).join("\u001f"))} -->`;
const lines = [];
const writeNode = (node, depth) => {
  const indent = "  ".repeat(depth);
  lines.push(`${indent}- ${node.label}: ${node.name}`);
  lines.push(`${indent}  ${lineFor(node)}`);
  if (node.detail) lines.push(`${indent}  > ${node.detail}`);
  for (const child of node.children ?? []) writeNode(child, depth + 1);
};
const roleNode = (role, scope) => ({
  kind: "role", label: "Role", id: `${scope}::${role.id}`, name: role.name,
  detail: role.responsibility, model: role.agentId, required: role.required,
  events: ["role.started", "role.completed", "role.failed"],
  children: [
    ...(role.skills ?? []).map((name) => ({ kind: "skill", label: "Skill", id: `${scope}::${role.id}::${name}`, name, detail: `Reusable skill used by ${role.name}.`, required: true, events: [], children: [] })),
    ...(role.tools ?? []).map((name) => ({ kind: "tool", label: "Tool", id: `${scope}::${role.id}::${name}`, name, detail: "Permitted runtime tool.", required: true, events: ["tool.started", "tool.completed", "tool.failed"], children: [] })),
  ],
});
const workUnitNode = (unit) => {
  const team = teamById.get(unit.workTeamId);
  return {
    kind: "work_unit", label: "Work Unit", id: unit.id, name: unit.name,
    detail: `Uses ${unit.skillId}. Inputs: ${(unit.inputs ?? []).join(", ")}.`, model: unit.model,
    required: !unit.optional, events: unit.emits ?? ["work_unit.started", "work_unit.completed", "work_unit.failed"],
    children: [
      ...(team ? [{ kind: "work_team", label: "Work Team", id: `${unit.id}::${team.id}`, name: team.name, detail: team.purpose, required: true, events: ["team.started", "team.completed", "team.failed"], children: team.roles.map((role) => roleNode(role, unit.id)) }] : []),
      ...(!team ? [{ kind: "skill", label: "Skill", id: `${unit.id}-skill`, name: unit.skillId, detail: "Skill invoked by this work unit.", required: true, events: [], children: [] }] : []),
      ...(unit.outputs ?? []).map((name) => ({ kind: "output", label: "Output", id: name, name, detail: "Durable workflow output.", required: !unit.optional, events: ["output.written", "output.validated", "output.failed"], children: [] })),
    ],
  };
};
const rootNode = {
  kind: "workflow", label: "Workflow Agent", id: workflow.id, name: workflow.name, detail: workflow.description,
  model: workflow.modelPolicy.defaultLocalModel, required: true,
  events: ["workflow.started", "workflow.completed", "workflow.failed"],
  children: plan.stages.map((stage) => ({
    kind: "phase", label: "Phase", id: stage.id, name: stage.name,
    detail: `${stage.execution} workflow phase.`, required: true,
    events: ["stage.started", "stage.completed", "stage.failed"],
    children: [{
      kind: "subphase", label: "Subphase", id: `${stage.id}-subphase`, name: stage.subgraphId ?? stage.graphId,
      detail: `Graph: ${stage.graphId}. Execution: ${stage.execution}.`, required: true,
      events: ["subgraph.started", "subgraph.completed", "subgraph.failed"], children: stage.workUnits.map(workUnitNode),
    }],
  })),
};
lines.push("---", "kind: apple-orchestrator-workflow-agent", `id: ${workflow.id}`, `name: ${workflow.name}`, `status: ${workflow.status}`, `domain: ${workflow.domain}`, `human_interaction: ${workflow.operatingMode.humanInteraction}`, `default_model: ${workflow.modelPolicy.defaultLocalModel}`, "---", "", `# ${workflow.name}`, "", workflow.description, "");
writeNode(rootNode, 0);
const target = path.join(path.dirname(workflowPath), `${workflow.id}.workflow-agent.md`);
fs.writeFileSync(target, `${lines.join("\n")}\n`, "utf8");
console.log(target);
