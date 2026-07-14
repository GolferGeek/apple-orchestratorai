import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import * as os from "node:os";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const ROOT_MARKER = "apple-orchestratorai";

function findRepoRoot(cwd: string): string {
  let current = cwd;
  while (true) {
    if (path.basename(current) === ROOT_MARKER) return current;
    if (fs.existsSync(path.join(current, "workflows")) && fs.existsSync(path.join(current, "schemas"))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) return cwd;
    current = parent;
  }
}

function stateDir(cwd: string, ...parts: string[]): string {
  const configured = process.env.APPLE_ORCHESTRATOR_STATE_DIR;
  if (configured) return path.join(configured, ...parts);
  return path.join(os.homedir(), "Library", "Application Support", "Apple Orchestrator AI", ...parts);
}

function ensureDir(dir: string): void {
  fs.mkdirSync(dir, { recursive: true });
}

function appendJsonl(filePath: string, value: unknown): void {
  ensureDir(path.dirname(filePath));
  fs.appendFileSync(filePath, `${JSON.stringify(value)}\n`, "utf8");
}

function readJsonObject(filePath: string): Record<string, unknown> {
  if (!fs.existsSync(filePath)) return {};
  try {
    const parsed = JSON.parse(fs.readFileSync(filePath, "utf8"));
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

function updateRunStatus(cwd: string, runId: string, patch: Record<string, unknown>): string {
  const filePath = path.join(stateDir(cwd, "runs"), `${safeId(runId)}.status.json`);
  const existing = readJsonObject(filePath);
  const next = {
    ...existing,
    runId,
    updatedAt: new Date().toISOString(),
    ...patch,
  };
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, JSON.stringify(next, null, 2), "utf8");
  writeSwiftRunRecord(cwd, runId);
  return filePath;
}

function statusForEventType(type: string): string | null {
  if (type.endsWith(".failed")) return "failed";
  if (type === "workflow.started") return "running";
  if (type === "workflow.resumed") return "running";
  if (type === "workflow.stopped") return "stopped";
  if (type === "work_unit.started") return "running";
  if (type === "team.started") return "running";
  if (type === "role.started") return "running";
  if (type === "workflow.paused") return "paused";
  if (type === "workflow.completed") return "completed";
  if (type === "workflow.failed") return "failed";
  if (type === "human_review.requested") return "awaiting_review";
  if (type === "human_review.completed") return "running";
  return null;
}

function appendStatusArray(existing: unknown, value: unknown): unknown[] {
  const current = Array.isArray(existing) ? existing : [];
  return [...current, value];
}

function uniqueStatusArray(existing: unknown, value: string): string[] {
  const current = Array.isArray(existing) ? existing.filter((item): item is string => typeof item === "string") : [];
  return current.includes(value) ? current : [...current, value];
}

function workflowDisplayId(workflowId: unknown): string {
  if (workflowId === "legal.document-onboarding") return "document-onboarding";
  return typeof workflowId === "string" && workflowId ? workflowId : "document-onboarding";
}

function workflowDisplayName(workflowId: string): string {
  if (workflowId === "document-onboarding" || workflowId === "legal.document-onboarding") return "Document Onboarding";
  return workflowId
    .split(/[._-]+/g)
    .filter(Boolean)
    .map((part) => part.slice(0, 1).toUpperCase() + part.slice(1))
    .join(" ");
}

function stageName(stageId: string): string {
  switch (stageId) {
    case "metadata":
      return "Metadata";
    case "classify":
      return "Classify";
    case "specialists":
      return "Specialists";
    case "synthesis":
      return "Synthesis";
    case "hitl_review":
      return "Human Review";
    case "report":
      return "Report";
    default:
      return stageId.replace(/[_-]+/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
  }
}

function stageRecordsFromEvents(events: Array<Record<string, unknown>>): Array<Record<string, unknown>> {
  const stageIds = ["metadata", "classify", "specialists", "synthesis", "hitl_review", "report"];
  const aliases: Record<string, string[]> = {
    metadata: ["metadata", "source_intake", "source-intake"],
    classify: ["classify", "routing"],
    specialists: ["specialists", "specialist", "specialist_review", "specialist-review"],
    synthesis: ["synthesis"],
    hitl_review: ["hitl_review", "human_review", "attorney_review"],
    report: ["report", "output"],
  };
  return stageIds.map((id) => {
    const stageAliases = aliases[id] ?? [id];
    const matching = events.filter((event) => typeof event.stageId === "string" && stageAliases.includes(event.stageId));
    let status = "defined";
    if (matching.some((event) => typeof event.type === "string" && event.type.endsWith(".failed"))) status = "failed";
    else if (matching.some((event) => event.type === "human_review.requested")) status = "waiting_for_human";
    else if (matching.some((event) => event.type === "work_unit.completed" || event.type === "stage.completed")) status = "completed";
    else if (matching.some((event) => event.type === "work_unit.started" || event.type === "team.started" || event.type === "role.started" || event.type === "stage.started")) status = "running";
    const latestSummary = [...matching].reverse().find((event) => typeof event.summary === "string")?.summary;
    return {
      id,
      name: stageName(id),
      status,
      summary: latestSummary ?? (status === "defined" ? "Waiting for workflow events." : stageName(id)),
    };
  });
}

function readJsonlObjects(filePath: string): Array<Record<string, unknown>> {
  if (!fs.existsSync(filePath)) return [];
  return fs.readFileSync(filePath, "utf8")
    .split("\n")
    .filter((line) => line.trim())
    .map((line) => {
      try {
        const parsed = JSON.parse(line);
        return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null;
      } catch {
        return null;
      }
    })
    .filter((item): item is Record<string, unknown> => Boolean(item));
}

function writeSwiftRunRecord(cwd: string, runId: string): void {
  const statusPath = path.join(stateDir(cwd, "runs"), `${safeId(runId)}.status.json`);
  const status = readJsonObject(statusPath);
  const workflowId = workflowDisplayId(status.workflowId);
  const events = readJsonlObjects(path.join(stateDir(cwd, "events"), `${safeId(runId)}.jsonl`));
  const firstTimestamp = typeof events[0]?.timestamp === "string" ? events[0].timestamp : typeof status.updatedAt === "string" ? status.updatedAt : new Date().toISOString();
  const latestStatus = typeof status.status === "string" ? status.status : events.length ? "running" : "defined";
  const client = status.client && typeof status.client === "object" && !Array.isArray(status.client)
    ? status.client as Record<string, unknown>
    : { id: "client-acme-robotics", name: "Acme Robotics LLC" };
  const matter = status.matter && typeof status.matter === "object" && !Array.isArray(status.matter)
    ? status.matter as Record<string, unknown>
    : { id: "matter-vendor-renewal-2026", name: "Vendor Agreement Renewal" };
  const pendingHumanReview = status.pendingHumanReview && typeof status.pendingHumanReview === "object" && !Array.isArray(status.pendingHumanReview)
    ? status.pendingHumanReview as Record<string, unknown>
    : null;
  const humanReview = pendingHumanReview
    ? {
        id: typeof pendingHumanReview.reviewId === "string" ? pendingHumanReview.reviewId : `${runId}-review`,
        status: "requested",
        title: typeof pendingHumanReview.title === "string" ? pendingHumanReview.title : "Human Review Required",
        summary: "Review the workflow output before finalization.",
        segments: [
          {
            id: "approval",
            label: "Approval",
            status: "pending",
            decision: null,
            summary: "Approve, modify, reject, or request changes.",
          },
        ],
      }
    : null;
  const artifacts = Array.isArray(status.artifacts) ? status.artifacts.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object" && !Array.isArray(item)) : [];
  const outputRecord = status.outputs && typeof status.outputs === "object" && !Array.isArray(status.outputs) ? status.outputs as Record<string, unknown> : {};
  const outputs = [
    ...artifacts.map((artifact) => ({
      id: typeof artifact.id === "string" ? artifact.id : "artifact",
      type: typeof artifact.type === "string" ? artifact.type : "text/plain",
      title: typeof artifact.title === "string" ? artifact.title : typeof artifact.id === "string" ? artifact.id : "Artifact",
      content: typeof artifact.uri === "string" ? artifact.uri : "",
    })),
    ...(typeof outputRecord.response === "string"
      ? [{
          id: "response",
          type: "markdown",
          title: "Workflow Response",
          content: outputRecord.response,
        }]
      : []),
  ];
  const record = {
    id: runId,
    workflowId,
    workflowName: workflowDisplayName(workflowId),
    status: latestStatus,
    profileId: typeof status.profileId === "string" ? status.profileId : "legal-dev",
    startedAt: firstTimestamp,
    completedAt: latestStatus === "completed" || latestStatus === "failed" ? status.updatedAt ?? new Date().toISOString() : null,
    client: {
      id: typeof client.id === "string" ? client.id : "client-acme-robotics",
      name: typeof client.name === "string" ? client.name : "Acme Robotics LLC",
    },
    matter: {
      id: typeof matter.id === "string" ? matter.id : "matter-vendor-renewal-2026",
      name: typeof matter.name === "string" ? matter.name : "Vendor Agreement Renewal",
    },
    stages: stageRecordsFromEvents(events),
    humanReview,
    outputs,
    events: [],
  };
  const recordPath = path.join(stateDir(cwd, "runs"), `${safeId(runId)}.json`);
  ensureDir(path.dirname(recordPath));
  fs.writeFileSync(recordPath, JSON.stringify(record, null, 2), "utf8");
}

function safeId(input: string): string {
  return input.replace(/[^a-zA-Z0-9_.-]+/g, "-").slice(0, 160);
}

function readTextFile(filePath: string): string {
  return fs.readFileSync(filePath, "utf8");
}

function localPath(inputPath: string): string {
  if (inputPath.startsWith("file://")) {
    return fileURLToPath(inputPath);
  }
  return inputPath;
}

function parseAgentFile(filePath: string): { frontmatter: Record<string, string>; body: string } {
  const content = fs.readFileSync(filePath, "utf8");
  if (!content.startsWith("---\n")) return { frontmatter: {}, body: content };
  const end = content.indexOf("\n---", 4);
  if (end < 0) return { frontmatter: {}, body: content };
  const frontmatterText = content.slice(4, end).trim();
  const body = content.slice(content.indexOf("\n", end + 4) + 1);
  const frontmatter: Record<string, string> = {};
  for (const line of frontmatterText.split("\n")) {
    const index = line.indexOf(":");
    if (index <= 0) continue;
    frontmatter[line.slice(0, index).trim()] = line.slice(index + 1).trim();
  }
  return { frontmatter, body };
}

function extractFinalAssistantText(stdout: string): string {
  let finalText = "";
  let parsedEvent = false;
  for (const line of stdout.split("\n")) {
    if (!line.trim()) continue;
    try {
      const event = JSON.parse(line);
      if (typeof event?.type !== "string") continue;
      parsedEvent = true;
      const message = event.message;
      if (event.type !== "message_end" || message?.role !== "assistant") continue;
      for (const part of message.content ?? []) {
        if (part.type === "text") finalText = part.text;
      }
    } catch {
      continue;
    }
  }
  return finalText || (parsedEvent ? "" : stdout.trim());
}

function resolveApprovedSpecPath(cwd: string, inputPath: string): string {
  const repoRoot = findRepoRoot(cwd);
  const resolved = path.resolve(repoRoot, localPath(inputPath));
  const approvedRoots = [
    stateDir(cwd, "agent-specs"),
    path.join(repoRoot, "workflows"),
    path.join(repoRoot, "test-fixtures"),
  ];
  if (!approvedRoots.some((root) => resolved === root || resolved.startsWith(`${root}${path.sep}`))) {
    throw new Error(`Agent spec path is outside approved roots: ${resolved}`);
  }
  return resolved;
}

function jsonStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function buildDynamicAgentPrompt(spec: Record<string, unknown>): string {
  const id = typeof spec.id === "string" ? spec.id : "dynamic-agent";
  const name = typeof spec.name === "string" ? spec.name : id;
  const description = typeof spec.description === "string" ? spec.description : "Ephemeral workflow role agent.";
  const role = typeof spec.role === "string" ? spec.role : "Perform the assigned workflow task.";
  const instructions = typeof spec.instructions === "string" ? spec.instructions : "";
  const outputContract = spec.outputContract ? JSON.stringify(spec.outputContract, null, 2) : "{}";
  const constraints = jsonStringArray(spec.constraints);
  const skills = jsonStringArray(spec.skills);

  return [
    `You are ${name} (${id}).`,
    "",
    description,
    "",
    "Role:",
    role,
    "",
    "Instructions:",
    instructions || "- Follow the task facts exactly and do not invent unavailable inputs.",
    "",
    "Relevant skills:",
    skills.length ? skills.map((skill) => `- ${skill}`).join("\n") : "- none specified",
    "",
    "Constraints:",
    constraints.length ? constraints.map((constraint) => `- ${constraint}`).join("\n") : "- Use only the facts supplied in the task.",
    "",
    "Required output contract:",
    "```json",
    outputContract,
    "```",
  ].join("\n");
}

function defaultModelForTier(tier: string | undefined): string {
  switch (tier) {
    case "fast":
      return "gemma4:e2b-mlx";
    case "standard":
      return "gemma4:e4b-mlx";
    case "reasoning":
      return "qwen3.6:27b-mlx";
    case "deep":
      return "qwen3.6:35b-mlx";
    default:
      return "gemma4:e4b-mlx";
  }
}

function usableModel(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  if (!trimmed || trimmed === "null" || trimmed === "undefined") return undefined;
  return trimmed;
}

function compactJson(value: unknown): string {
  return JSON.stringify(value, null, 2);
}

function compactAgentDetails(details: Record<string, unknown>): Record<string, unknown> {
  return {
    agent: details.agent,
    agentPath: details.agentPath,
    model: details.model,
    modelSource: details.modelSource,
    modelOverrideReason: details.modelOverrideReason,
    ignoredModelOverride: details.ignoredModelOverride,
    status: details.status,
    signal: details.signal,
    stderr: typeof details.stderr === "string" ? details.stderr.slice(0, 2000) : details.stderr,
  };
}

function compactRoleOutputsForContext(roleOutputs: Array<Record<string, unknown>>): Array<Record<string, unknown>> {
  return roleOutputs.map((roleOutput) => ({
    roleId: roleOutput.roleId,
    agentId: roleOutput.agentId,
    skillId: roleOutput.skillId,
    failed: roleOutput.failed,
    output: typeof roleOutput.output === "string" ? roleOutput.output.slice(0, 4000) : roleOutput.output,
  }));
}

function appendWorkflowEvent(cwd: string, event: Record<string, unknown>): string {
  const runId = typeof event.runId === "string" ? event.runId : "unknown-run";
  const filePath = path.join(stateDir(cwd, "events"), `${safeId(runId)}.jsonl`);
  appendJsonl(filePath, event);

  const type = typeof event.type === "string" ? event.type : "";
  const statusPatch: Record<string, unknown> = {
    workflowId: event.workflowId,
    latestEvent: event,
    latestEventType: type,
    latestSummary: typeof event.summary === "string" ? event.summary : typeof event.message === "string" ? event.message : null,
  };
  if (event.raw && typeof event.raw === "object" && !Array.isArray(event.raw)) {
    const raw = event.raw as Record<string, unknown>;
    if (raw.client && typeof raw.client === "object" && !Array.isArray(raw.client)) statusPatch.client = raw.client;
    if (raw.matter && typeof raw.matter === "object" && !Array.isArray(raw.matter)) statusPatch.matter = raw.matter;
    if (typeof raw.profileId === "string") statusPatch.profileId = raw.profileId;
  }
  const lifecycleStatus = statusForEventType(type);
  if (lifecycleStatus) statusPatch.status = lifecycleStatus;
  const statusPath = path.join(stateDir(cwd, "runs"), `${safeId(runId)}.status.json`);
  const existingStatus = readJsonObject(statusPath);
  if (type === "team.started" && typeof event.teamId === "string") {
    statusPatch.activeTeamId = event.teamId;
    statusPatch.startedTeamIds = uniqueStatusArray(existingStatus.startedTeamIds, event.teamId);
  }
  if (type === "team.completed" && typeof event.teamId === "string") {
    statusPatch.activeTeamId = null;
    statusPatch.completedTeamIds = uniqueStatusArray(existingStatus.completedTeamIds, event.teamId);
  }
  if (type === "team.failed" && typeof event.teamId === "string") {
    statusPatch.activeTeamId = null;
    statusPatch.failedTeamIds = uniqueStatusArray(existingStatus.failedTeamIds, event.teamId);
  }
  if (type === "role.started" && typeof event.roleId === "string") {
    statusPatch.activeRoleId = event.roleId;
    statusPatch.startedRoleIds = uniqueStatusArray(existingStatus.startedRoleIds, event.roleId);
  }
  if (type === "role.completed" && typeof event.roleId === "string") {
    statusPatch.activeRoleId = null;
    statusPatch.completedRoleIds = uniqueStatusArray(existingStatus.completedRoleIds, event.roleId);
  }
  if (type === "role.failed" && typeof event.roleId === "string") {
    statusPatch.activeRoleId = null;
    statusPatch.failedRoleIds = uniqueStatusArray(existingStatus.failedRoleIds, event.roleId);
  }
  if (type === "work_unit.started" && typeof event.workUnitId === "string") {
    statusPatch.activeWorkUnitId = event.workUnitId;
    statusPatch.startedWorkUnitIds = uniqueStatusArray(existingStatus.startedWorkUnitIds, event.workUnitId);
  }
  if (type === "work_unit.completed" && typeof event.workUnitId === "string") {
    statusPatch.activeWorkUnitId = null;
    statusPatch.completedWorkUnitIds = uniqueStatusArray(existingStatus.completedWorkUnitIds, event.workUnitId);
  }
  if (type === "work_unit.failed" && typeof event.workUnitId === "string") {
    statusPatch.activeWorkUnitId = null;
    statusPatch.failedWorkUnitIds = uniqueStatusArray(existingStatus.failedWorkUnitIds, event.workUnitId);
  }
  updateRunStatus(cwd, runId, statusPatch);
  return filePath;
}

function appendWorkflowRunEntry(cwd: string, runId: string, entryType: string, data: Record<string, unknown>): string {
  const entry = {
    timestamp: new Date().toISOString(),
    runId,
    entryType,
    data,
  };
  const filePath = path.join(stateDir(cwd, "runs"), `${safeId(runId)}.entries.jsonl`);
  appendJsonl(filePath, entry);
  const statusPath = path.join(stateDir(cwd, "runs"), `${safeId(runId)}.status.json`);
  const existingStatus = readJsonObject(statusPath);
  updateRunStatus(cwd, runId, {
    latestRunEntry: entry,
    latestRunEntryType: entryType,
    completedRunEntryTypes: appendStatusArray(existingStatus.completedRunEntryTypes, entryType),
  });
  return filePath;
}

type AgentRunRequest = {
  agent: string;
  task: string;
  skillId?: string;
  model?: string;
  modelOverrideReason?: string;
  modelTier?: "fast" | "standard" | "reasoning" | "deep";
  timeoutSeconds?: number;
};

function workflowAgentPath(repoRoot: string, workflowId: string): string {
  const workflowName = safeId(workflowId.split(".").pop() || workflowId);
  return path.join(repoRoot, "workflows", "legal", `${workflowName}.workflow-agent.md`);
}

function decodeWorkflowNodeField(value: string): string {
  // WorkflowAgentFileStore writes standard Base64 and replaces '=' padding with '_'.
  const base64 = value.replace(/_/g, "=");
  return Buffer.from(base64, "base64").toString("utf8");
}

function workflowRoleAgents(repoRoot: string, workflowId: string): Record<string, string> {
  const filePath = workflowAgentPath(repoRoot, workflowId);
  if (!fs.existsSync(filePath)) return {};
  const text = fs.readFileSync(filePath, "utf8");
  const roles: Record<string, string> = {};
  const expression = /<!-- ao-node kind=role\s+([^>]*)-->/g;
  for (const match of text.matchAll(expression)) {
    const id = /(?:^|\s)id=([^\s]+)/.exec(match[1])?.[1];
    const agent = /(?:^|\s)model=([^\s]+)/.exec(match[1])?.[1];
    if (!id || !agent) continue;
    const roleId = decodeWorkflowNodeField(id);
    const agentId = decodeWorkflowNodeField(agent);
    if (roleId && agentId) roles[roleId] = agentId;
  }
  return roles;
}

function invocationContracts(repoRoot: string, workflowId: string): Record<string, string> {
  const filePath = workflowAgentPath(repoRoot, workflowId);
  if (!fs.existsSync(filePath)) return {};
  const text = fs.readFileSync(filePath, "utf8");
  const contracts: Record<string, string> = {};
  const expression = /<!-- ao-invocation-contract id="([^"]+)" -->\n([\s\S]*?)<!-- \/ao-invocation-contract -->/g;
  for (const match of text.matchAll(expression)) {
    contracts[match[1]] = match[2].trim();
  }
  return contracts;
}

function contractIdForRole(roleId: string, agentId: string): string[] {
  const ids = [roleId, `agent:${agentId}`];
  if (roleId.endsWith("-specialist")) ids.push("specialist-lane-role");
  if (agentId === "legal-quality-reviewer") ids.push("quality-reviewer-role");
  if (agentId === "legal-arbitrator") ids.push("arbitrator-role");
  return ids;
}

function interpolateContract(contract: string, values: Record<string, unknown>): string {
  return contract
    .replaceAll("{{RUN_CONTEXT}}", compactJson(values.runContext ?? {}))
    .replaceAll("{{PREVIOUS_ROLE_OUTPUTS}}", compactJson(values.previousRoleOutputs ?? []));
}

function buildRoleInvocationPrompt(
  repoRoot: string,
  params: Record<string, unknown>,
  role: Record<string, unknown>,
  previousRoleOutputs: Array<Record<string, unknown>>
): string {
  const runContext = {
    runId: params.runId,
    workflowId: params.workflowId,
    graphId: params.graphId ?? null,
    subgraphId: params.subgraphId ?? null,
    stageId: params.stageId ?? null,
    workUnitId: params.workUnitId,
    teamId: params.teamId,
    roleId: role.roleId,
    agentId: role.agent,
    skillId: role.skillId ?? null,
    modelRoute: {
      requestedModel: role.model ?? null,
      modelTier: role.modelTier ?? null,
      overrideReason: role.modelOverrideReason ?? null,
      policy: (params.sharedContext as Record<string, unknown> | undefined)?.modelPolicy ?? null,
    },
    sourceAndMatterContext: params.sharedContext ?? {},
  };

  const contracts = invocationContracts(repoRoot, String(params.workflowId ?? ""));
  const specific = contractIdForRole(String(role.roleId ?? ""), String(role.agent ?? ""))
    .map((id) => contracts[id])
    .find(Boolean);
  const contractParts = [
    contracts["workflow-operating-contract"],
    contracts["legal-role-base"],
    specific,
  ].filter((part): part is string => Boolean(part));

  if (contractParts.length !== 3) {
    const missing = [
      !contracts["workflow-operating-contract"] ? "workflow-operating-contract" : null,
      !contracts["legal-role-base"] ? "legal-role-base" : null,
      !specific ? `role contract for ${String(role.roleId ?? "unknown-role")}` : null,
    ].filter((item): item is string => Boolean(item));
    throw new Error(
      `Workflow agent Markdown is incomplete for ${String(params.workflowId ?? "unknown-workflow")}: missing ${missing.join(", ")}. ` +
      "Define it in the Workflow Agent Builder before running this team."
    );
  }

  return interpolateContract(contractParts.join("\n\n"), { runContext, previousRoleOutputs });
}

function runAgentSpec(cwd: string, params: AgentRunRequest): {
  output: string;
  details: Record<string, unknown>;
  failed: boolean;
} {
  const repoRoot = findRepoRoot(cwd);
  const agentPath = path.join(repoRoot, ".pi", "agents", `${safeId(params.agent)}.md`);
  if (!fs.existsSync(agentPath)) {
    const agentsDir = path.join(repoRoot, ".pi", "agents");
    const available = fs.existsSync(agentsDir)
      ? fs.readdirSync(agentsDir).filter((name) => name.endsWith(".md")).map((name) => path.basename(name, ".md"))
      : [];
    return {
      output: `Unknown project agent: ${params.agent}. Available agents: ${available.join(", ") || "none"}`,
      details: { agent: params.agent, available },
      failed: true,
    };
  }

  const { frontmatter, body } = parseAgentFile(agentPath);
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "apple-orchestrator-agent-"));
  const systemPromptPath = path.join(tmpDir, `${safeId(params.agent)}.md`);
  fs.writeFileSync(
    systemPromptPath,
    body.trim(),
    "utf8"
  );

  const piBin = path.join(repoRoot, ".runtime", "pi", "packages", "coding-agent", "dist", "cli.js");
  const nodeBin = process.execPath;
  const agentTools = frontmatter.tools?.split(",").map((tool) => tool.trim()).filter(Boolean).join(",");
  const selectedSkillId = (params.skillId ?? frontmatter.skill?.trim()) || undefined;
  const skillDirectory = selectedSkillId
    ? path.join(repoRoot, ".pi", "skills", safeId(selectedSkillId))
    : null;
  const hasSelectedSkill = Boolean(skillDirectory && fs.existsSync(path.join(skillDirectory, "SKILL.md")));
  if (selectedSkillId && !hasSelectedSkill) {
    return {
      output: `Unknown project skill: ${selectedSkillId}. Define the skill at .pi/skills/${safeId(selectedSkillId)}/SKILL.md before assigning it to a workflow role.`,
      details: { agent: params.agent, skillId: selectedSkillId, skillDirectory },
      failed: true,
    };
  }
  const requestedModel = usableModel(params.model);
  const frontmatterModel = usableModel(frontmatter.model);
  const selectedModel = requestedModel && params.modelOverrideReason
    ? requestedModel
    : frontmatterModel ?? defaultModelForTier(params.modelTier);
  const ignoredModelOverride = requestedModel && !params.modelOverrideReason ? requestedModel : null;
  const args = [
    piBin,
    "--mode",
    "text",
    "-p",
    "--no-session",
    "--provider",
    "ollama",
    "--api-key",
    "ollama",
    "--model",
    selectedModel,
    "--append-system-prompt",
    systemPromptPath,
  ];
  if (hasSelectedSkill && skillDirectory && selectedSkillId) {
    args.push("--skill", skillDirectory);
  } else {
    args.push("--no-skills");
  }
  if (agentTools) {
    args.push("--tools", agentTools);
  } else {
    args.push("--no-tools");
  }
  args.push([
    ...(hasSelectedSkill && selectedSkillId ? [`/skill:${selectedSkillId}`, ""] : []),
    "Bounded work-unit invocation:",
    "Follow the agent contract and this work-unit brief. Return compact, role-specific output only. Prefer valid JSON when the required packet is structured. Do not include hidden reasoning or generic process narration. Keep the answer under 1200 words unless the required artifact needs more space.",
    "",
    params.task,
  ].join("\n"));

  const result = spawnSync(nodeBin, args, {
    cwd: repoRoot,
    env: { ...process.env, PI_OFFLINE: process.env.PI_OFFLINE ?? "1" },
    encoding: "utf8",
    timeout: Math.max(1, params.timeoutSeconds ?? 90) * 1000,
    maxBuffer: 1024 * 1024 * 16,
  });

  try {
    fs.unlinkSync(systemPromptPath);
    fs.rmdirSync(tmpDir);
  } catch {
    /* ignore cleanup failures */
  }

  const output = extractFinalAssistantText(result.stdout ?? "");
  const failed = Boolean(result.error) || (result.status ?? 0) !== 0 || !output;
  return {
    output: output || result.stderr || result.error?.message || `Agent ${params.agent} produced no output.`,
    details: {
      agent: params.agent,
      agentPath,
      model: selectedModel,
      modelSource: requestedModel && params.modelOverrideReason ? "tool-param" : frontmatterModel ? "agent-frontmatter" : params.modelTier ? "tool-tier" : "tool-default",
      modelOverrideReason: params.modelOverrideReason ?? null,
      ignoredModelOverride,
      status: result.status,
      signal: result.signal,
      stderr: result.stderr,
      stdoutTail: (result.stdout ?? "").slice(-4000),
    },
    failed,
  };
}

function approvedLocalWorkflowPath(cwd: string, inputPath: string): string {
  const repoRoot = findRepoRoot(cwd);
  const resolved = path.resolve(repoRoot, localPath(inputPath));
  const approvedRoots = [
    path.join(repoRoot, "test-fixtures"),
    stateDir(cwd, "documents"),
  ];
  if (!approvedRoots.some((root) => resolved === root || resolved.startsWith(`${root}${path.sep}`))) {
    throw new Error(`Path is outside approved workflow document roots: ${resolved}`);
  }
  return resolved;
}

const WorkflowEvent = Type.Object({
  runId: Type.String(),
  type: Type.Union([
    Type.Literal("workflow.started"),
    Type.Literal("workflow.paused"),
    Type.Literal("workflow.completed"),
    Type.Literal("workflow.failed"),
    Type.Literal("graph.started"),
    Type.Literal("graph.completed"),
    Type.Literal("graph.failed"),
    Type.Literal("subgraph.started"),
    Type.Literal("subgraph.completed"),
    Type.Literal("subgraph.failed"),
    Type.Literal("stage.started"),
    Type.Literal("stage.completed"),
    Type.Literal("stage.failed"),
    Type.Literal("work_unit.started"),
    Type.Literal("work_unit.completed"),
    Type.Literal("work_unit.failed"),
    Type.Literal("team.started"),
    Type.Literal("team.completed"),
    Type.Literal("team.failed"),
    Type.Literal("role.started"),
    Type.Literal("role.completed"),
    Type.Literal("role.failed"),
    Type.Literal("tool.started"),
    Type.Literal("tool.completed"),
    Type.Literal("tool.failed"),
    Type.Literal("human_review.requested"),
    Type.Literal("human_review.completed"),
    Type.Literal("human_review.failed"),
    Type.Literal("output.written"),
    Type.Literal("output.validated"),
    Type.Literal("output.failed"),
  ]),
  workflowId: Type.Optional(Type.String()),
  graphId: Type.Optional(Type.String()),
  subgraphId: Type.Optional(Type.String()),
  stageId: Type.Optional(Type.String()),
  workUnitId: Type.Optional(Type.String()),
  teamId: Type.Optional(Type.String()),
  roleId: Type.Optional(Type.String()),
  agentId: Type.Optional(Type.String()),
  skillId: Type.Optional(Type.String()),
  toolCallId: Type.Optional(Type.String()),
  status: Type.Optional(Type.String()),
  summary: Type.Optional(Type.String()),
  message: Type.Optional(Type.String()),
  raw: Type.Optional(Type.Record(Type.String(), Type.Unknown())),
});

const emitEventTool = defineTool({
  name: "workflow_emit_event",
  label: "Workflow Event",
  description: "Persist a normalized workflow event for Apple Orchestrator AI observability.",
  promptSnippet: "Emit workflow, graph, subgraph, work-unit, team, role, HITL, and output events",
  parameters: WorkflowEvent,
  async execute(toolCallId, params, _signal, _onUpdate, ctx) {
    const event = {
      timestamp: new Date().toISOString(),
      ...params,
      toolCallId: params.toolCallId ?? toolCallId,
    };
    const filePath = appendWorkflowEvent(ctx.cwd, event);
    return {
      content: [{ type: "text", text: `Event emitted: ${params.type}` }],
      details: { event, filePath },
    };
  },
});

const appendRunEntryTool = defineTool({
  name: "workflow_append_run_entry",
  label: "Workflow Run Entry",
  description: "Append a durable workflow run entry that is not necessarily shown to the model.",
  parameters: Type.Object({
    runId: Type.Optional(Type.String()),
    entryType: Type.String(),
    data: Type.Union([Type.Record(Type.String(), Type.Unknown()), Type.String()]),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    let data: Record<string, unknown>;
    if (typeof params.data === "string") {
      try {
        const parsed = JSON.parse(params.data);
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
          return {
            content: [{ type: "text", text: "workflow_append_run_entry data string must parse to a JSON object." }],
            details: { params },
            isError: true,
          };
        }
        data = parsed as Record<string, unknown>;
      } catch (error) {
        return {
          content: [{ type: "text", text: `workflow_append_run_entry data string is not valid JSON: ${error instanceof Error ? error.message : "unknown parse error"}` }],
          details: { params },
          isError: true,
        };
      }
    } else {
      data = params.data;
    }
    const nestedRunId = typeof data.runId === "string" ? data.runId : undefined;
    const runId = params.runId ?? nestedRunId;
    if (!runId) {
      return {
        content: [{ type: "text", text: "workflow_append_run_entry requires runId at the top level or data.runId." }],
        details: { params },
        isError: true,
      };
    }
    const filePath = appendWorkflowRunEntry(ctx.cwd, runId, params.entryType, data);
    return {
      content: [{ type: "text", text: `Run entry appended: ${params.entryType}` }],
      details: { runId, entryType: params.entryType, data, filePath },
    };
  },
});

const callAgentTool = defineTool({
  name: "workflow_call_agent",
  label: "Apple Orchestrator Agent",
  description: "Call an Apple Orchestrator project-local agent spec from .pi/agents with an isolated Pi child process and return its final output.",
  parameters: Type.Object({
    agent: Type.String(),
    task: Type.String(),
    runId: Type.Optional(Type.String()),
    model: Type.Optional(Type.String()),
    modelOverrideReason: Type.Optional(Type.String()),
    modelTier: Type.Optional(Type.Union([
      Type.Literal("fast"),
      Type.Literal("standard"),
      Type.Literal("reasoning"),
      Type.Literal("deep"),
    ])),
    timeoutSeconds: Type.Optional(Type.Number()),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const result = runAgentSpec(ctx.cwd, params);
    return {
      content: [{ type: "text", text: result.output }],
      details: result.details,
      isError: result.failed,
    };
  },
});

const TeamRole = Type.Object({
  roleId: Type.String(),
  agent: Type.Optional(Type.String()),
  // The executable role brief is resolved from the workflow agent Markdown.
  // Keep this optional only for compatibility with older callers.
  task: Type.Optional(Type.String()),
  skillId: Type.Optional(Type.String()),
  outputEntryType: Type.Optional(Type.String()),
  required: Type.Optional(Type.Boolean()),
  model: Type.Optional(Type.String()),
  modelOverrideReason: Type.Optional(Type.String()),
  modelTier: Type.Optional(Type.Union([
    Type.Literal("fast"),
    Type.Literal("standard"),
    Type.Literal("reasoning"),
    Type.Literal("deep"),
  ])),
  timeoutSeconds: Type.Optional(Type.Number()),
});

const runTeamTool = defineTool({
  name: "workflow_run_team",
  label: "Workflow Team",
  description: "Run an Apple Orchestrator work team from its workflow agent Markdown, invoke ordered role agents, emit team/role events, and persist role outputs.",
  parameters: Type.Object({
    runId: Type.String(),
    workflowId: Type.String(),
    workUnitId: Type.String(),
    teamId: Type.String(),
    graphId: Type.Optional(Type.String()),
    subgraphId: Type.Optional(Type.String()),
    stageId: Type.Optional(Type.String()),
    summary: Type.Optional(Type.String()),
    sharedContext: Type.Record(Type.String(), Type.Unknown()),
    passPreviousRoleOutputs: Type.Optional(Type.Boolean()),
    roles: Type.Array(TeamRole),
  }),
  async execute(toolCallId, params, _signal, _onUpdate, ctx) {
    const startedAt = new Date().toISOString();
    const correlation = {
      runId: params.runId,
      workflowId: params.workflowId,
      graphId: params.graphId,
      subgraphId: params.subgraphId,
      stageId: params.stageId,
      workUnitId: params.workUnitId,
      teamId: params.teamId,
    };

    appendWorkflowEvent(ctx.cwd, {
      timestamp: startedAt,
      type: "work_unit.started",
      toolCallId,
      summary: params.summary ?? `Work unit started: ${params.workUnitId}`,
      ...correlation,
    });
    appendWorkflowEvent(ctx.cwd, {
      timestamp: startedAt,
      type: "team.started",
      toolCallId,
      summary: params.summary ?? `Team started: ${params.teamId}`,
      ...correlation,
    });

    const roleOutputs: Array<Record<string, unknown>> = [];
    const passPreviousRoleOutputs = params.passPreviousRoleOutputs ?? true;

    const roleAgents = workflowRoleAgents(findRepoRoot(ctx.cwd), params.workflowId);

    for (const requestedRole of params.roles) {
      const expectedAgent = roleAgents[requestedRole.roleId];
      const role = {
        ...requestedRole,
        agent: expectedAgent ?? "workflow-agent-definition-missing",
      };
      const roleDefinitionError = !expectedAgent
        ? `Workflow agent Markdown has no agent definition for role ${requestedRole.roleId}.`
        : requestedRole.agent && requestedRole.agent !== expectedAgent
          ? `Workflow agent Markdown assigns ${requestedRole.roleId} to ${expectedAgent}, not ${requestedRole.agent}.`
          : null;
      const roleStartedAt = new Date().toISOString();
      appendWorkflowEvent(ctx.cwd, {
        timestamp: roleStartedAt,
        type: "role.started",
        toolCallId,
        roleId: role.roleId,
        agentId: role.agent,
        skillId: role.skillId,
        summary: `Role started: ${role.roleId}`,
        ...correlation,
      });

      const result = (() => {
        try {
          if (roleDefinitionError) throw new Error(roleDefinitionError);
          const task = buildRoleInvocationPrompt(
            findRepoRoot(ctx.cwd),
            params as Record<string, unknown>,
            role as Record<string, unknown>,
            passPreviousRoleOutputs ? compactRoleOutputsForContext(roleOutputs) : []
          );
          return runAgentSpec(ctx.cwd, {
            agent: role.agent,
            task,
            skillId: role.skillId,
            model: role.model,
            modelOverrideReason: role.modelOverrideReason,
            modelTier: role.modelTier,
            timeoutSeconds: role.timeoutSeconds,
          });
        } catch (error) {
          return {
            output: error instanceof Error ? error.message : String(error),
            details: { workflowAgentContractError: true },
            failed: true,
          };
        }
      })();

      const rolePacket = {
        roleId: role.roleId,
        agentId: role.agent,
        skillId: role.skillId ?? null,
        required: role.required ?? true,
        output: result.output,
        details: compactAgentDetails(result.details),
        failed: result.failed,
      };
      const entryType = role.outputEntryType ?? `${params.teamId}.${role.roleId}`;
      appendWorkflowRunEntry(ctx.cwd, params.runId, entryType, {
        workflowId: params.workflowId,
        workUnitId: params.workUnitId,
        teamId: params.teamId,
        ...rolePacket,
      });
      roleOutputs.push(rolePacket);

      if (result.failed && (role.required ?? true)) {
        const failedAt = new Date().toISOString();
        appendWorkflowEvent(ctx.cwd, {
          timestamp: failedAt,
          type: "role.failed",
          toolCallId,
          roleId: role.roleId,
          agentId: role.agent,
          skillId: role.skillId,
          summary: `Required role failed: ${role.roleId}`,
          raw: { output: result.output, details: result.details },
          ...correlation,
        });
        appendWorkflowEvent(ctx.cwd, {
          timestamp: failedAt,
          type: "team.failed",
          toolCallId,
          summary: `Team failed: ${params.teamId}`,
          raw: { failedRoleId: role.roleId },
          ...correlation,
        });
        appendWorkflowEvent(ctx.cwd, {
          timestamp: failedAt,
          type: "work_unit.failed",
          toolCallId,
          summary: `Work unit failed: ${params.workUnitId}`,
          raw: { failedTeamId: params.teamId, failedRoleId: role.roleId },
          ...correlation,
        });
        return {
          content: [{ type: "text", text: `Team failed at required role ${role.roleId}: ${result.output}` }],
          details: {
            runId: params.runId,
            workflowId: params.workflowId,
            workUnitId: params.workUnitId,
            teamId: params.teamId,
            status: "failed",
            failedRoleId: role.roleId,
            roleOutputs,
          },
          isError: true,
        };
      }

      appendWorkflowEvent(ctx.cwd, {
        timestamp: new Date().toISOString(),
        type: result.failed ? "role.failed" : "role.completed",
        toolCallId,
        roleId: role.roleId,
        agentId: role.agent,
        skillId: role.skillId,
        summary: result.failed ? `Optional role failed: ${role.roleId}` : `Role completed: ${role.roleId}`,
        raw: { outputPreview: result.output.slice(0, 2000), details: compactAgentDetails(result.details) },
        ...correlation,
      });
    }

    const completedAt = new Date().toISOString();
    const teamPacket = {
      runId: params.runId,
      workflowId: params.workflowId,
      workUnitId: params.workUnitId,
      teamId: params.teamId,
      status: "completed",
      startedAt,
      completedAt,
      roleOutputs,
    };
    appendWorkflowRunEntry(ctx.cwd, params.runId, `${params.teamId}.team_output`, teamPacket);
    appendWorkflowEvent(ctx.cwd, {
      timestamp: completedAt,
      type: "team.completed",
      toolCallId,
      summary: `Team completed: ${params.teamId}`,
      raw: { roleCount: roleOutputs.length },
      ...correlation,
    });
    appendWorkflowEvent(ctx.cwd, {
      timestamp: completedAt,
      type: "work_unit.completed",
      toolCallId,
      summary: `Work unit completed: ${params.workUnitId}`,
      raw: { teamId: params.teamId },
      ...correlation,
    });

    return {
      content: [{ type: "text", text: compactJson(teamPacket) }],
      details: teamPacket,
    };
  },
});

const callDynamicAgentTool = defineTool({
  name: "workflow_call_dynamic_agent",
  label: "Dynamic Workflow Agent",
  description: "Create an ephemeral specialized Pi agent from a validated JSON spec and run it for one workflow task.",
  parameters: Type.Object({
    runId: Type.String(),
    specPath: Type.Optional(Type.String()),
    spec: Type.Optional(Type.Record(Type.String(), Type.Unknown())),
    task: Type.String(),
    model: Type.Optional(Type.String()),
    modelOverrideReason: Type.Optional(Type.String()),
    modelTier: Type.Optional(Type.Union([
      Type.Literal("fast"),
      Type.Literal("standard"),
      Type.Literal("reasoning"),
      Type.Literal("deep"),
    ])),
    timeoutSeconds: Type.Optional(Type.Number()),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const repoRoot = findRepoRoot(ctx.cwd);
    let spec: Record<string, unknown> | undefined = params.spec;
    let specPath: string | null = null;

    try {
      if (!spec && params.specPath) {
        specPath = resolveApprovedSpecPath(ctx.cwd, params.specPath);
        spec = JSON.parse(fs.readFileSync(specPath, "utf8"));
      }
    } catch (error) {
      return {
        content: [{ type: "text", text: error instanceof Error ? error.message : "Unable to read dynamic agent spec." }],
        details: { specPath: params.specPath },
        isError: true,
      };
    }

    if (!spec || typeof spec !== "object") {
      return {
        content: [{ type: "text", text: "workflow_call_dynamic_agent requires either spec or specPath." }],
        details: { params },
        isError: true,
      };
    }

    const id = typeof spec.id === "string" ? safeId(spec.id) : `dynamic-agent-${Date.now()}`;
    const allowedTools = jsonStringArray(spec.allowedTools);
    const blockedTools = ["workflow_write_artifact", "workflow_structured_output", "workflow_request_human_review"];
    const tools = allowedTools.filter((tool) => !blockedTools.includes(tool)).join(",");
    const systemPrompt = buildDynamicAgentPrompt(spec);

    const specOutDir = stateDir(ctx.cwd, "agent-specs", safeId(params.runId));
    ensureDir(specOutDir);
    const specOutPath = path.join(specOutDir, `${id}.json`);
    fs.writeFileSync(specOutPath, JSON.stringify({ ...spec, runId: params.runId }, null, 2), "utf8");

    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "apple-orchestrator-dynamic-agent-"));
    const systemPromptPath = path.join(tmpDir, `${id}.md`);
    fs.writeFileSync(systemPromptPath, systemPrompt, "utf8");

    const piBin = path.join(repoRoot, ".runtime", "pi", "packages", "coding-agent", "dist", "cli.js");
    const requestedModel = usableModel(params.model);
    const specModel = usableModel(spec.model);
    const selectedModel = requestedModel && params.modelOverrideReason
      ? requestedModel
      : specModel ?? defaultModelForTier(params.modelTier);
    const ignoredModelOverride = requestedModel && !params.modelOverrideReason ? requestedModel : null;
    const args = [
      piBin,
      "--mode",
      "text",
      "-p",
      "--no-session",
      "--provider",
      "ollama",
      "--api-key",
      "ollama",
      "--model",
      selectedModel,
      "--append-system-prompt",
      systemPromptPath,
      "--skill",
      path.join(repoRoot, ".pi", "skills"),
    ];
    if (tools) {
      args.push("--tools", tools);
    } else {
      args.push("--no-tools");
    }
    args.push([
      "Task:",
      "Return compact, role-specific output only. Prefer valid JSON when the task asks for structured output. Do not include process narration or hidden reasoning. Keep the answer under 1200 words unless the task explicitly requires a longer artifact.",
      "",
      params.task,
    ].join("\n"));

    const result = spawnSync(process.execPath, args, {
      cwd: repoRoot,
      env: { ...process.env, PI_OFFLINE: process.env.PI_OFFLINE ?? "1" },
      encoding: "utf8",
      timeout: Math.max(1, params.timeoutSeconds ?? 90) * 1000,
      maxBuffer: 1024 * 1024 * 16,
    });

    try {
      fs.unlinkSync(systemPromptPath);
      fs.rmdirSync(tmpDir);
    } catch {
      /* ignore cleanup failures */
    }

    const output = extractFinalAssistantText(result.stdout ?? "");
    const failed = Boolean(result.error) || (result.status ?? 0) !== 0 || !output;
    return {
      content: [{ type: "text", text: output || result.stderr || result.error?.message || `Dynamic agent ${id} produced no output.` }],
      details: {
        agentId: id,
        specPath,
        storedSpecPath: specOutPath,
        model: selectedModel,
        modelSource: requestedModel && params.modelOverrideReason ? "tool-param" : specModel ? "dynamic-agent-spec" : params.modelTier ? "tool-tier" : "tool-default",
        modelOverrideReason: params.modelOverrideReason ?? null,
        ignoredModelOverride,
        status: result.status,
        signal: result.signal,
        stderr: result.stderr,
        stdoutTail: (result.stdout ?? "").slice(-50000),
      },
      isError: failed,
    };
  },
});

const promoteDynamicAgentTool = defineTool({
  name: "workflow_promote_dynamic_agent",
  label: "Promote Dynamic Agent",
  description: "Promote an accepted dynamic agent JSON spec into a permanent Apple Orchestrator project-local .pi/agents markdown file.",
  parameters: Type.Object({
    runId: Type.String(),
    specPath: Type.String(),
    acceptedBy: Type.Optional(Type.String()),
    overwrite: Type.Optional(Type.Boolean()),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const repoRoot = findRepoRoot(ctx.cwd);
    let specPath: string;
    let spec: Record<string, unknown>;
    try {
      specPath = resolveApprovedSpecPath(ctx.cwd, params.specPath);
      spec = JSON.parse(fs.readFileSync(specPath, "utf8"));
    } catch (error) {
      return {
        content: [{ type: "text", text: error instanceof Error ? error.message : "Unable to read dynamic agent spec." }],
        details: { specPath: params.specPath },
        isError: true,
      };
    }

    const id = typeof spec.id === "string" ? safeId(spec.id) : "";
    if (!id) {
      return {
        content: [{ type: "text", text: "Dynamic agent spec requires a string id before promotion." }],
        details: { specPath },
        isError: true,
      };
    }

    const agentPath = path.join(repoRoot, ".pi", "agents", `${id}.md`);
    if (fs.existsSync(agentPath) && !params.overwrite) {
      return {
        content: [{ type: "text", text: `Permanent agent already exists: ${agentPath}` }],
        details: { agentPath },
        isError: true,
      };
    }

    const name = typeof spec.name === "string" ? spec.name : id;
    const description = typeof spec.description === "string" ? spec.description : `Promoted dynamic workflow agent: ${name}`;
    const model = typeof spec.model === "string" ? spec.model : "gemma4:e4b-mlx";
    const allowedTools = jsonStringArray(spec.allowedTools).filter((tool) => !["workflow_write_artifact", "workflow_structured_output", "workflow_request_human_review"].includes(tool));
    const body = buildDynamicAgentPrompt(spec);
    const content = [
      "---",
      `name: ${id}`,
      `description: ${description.replace(/\n/g, " ")}`,
      allowedTools.length ? `tools: ${allowedTools.join(", ")}` : null,
      `model: ${model}`,
      "---",
      "",
      body,
      "",
      "Promotion metadata:",
      "",
      `- promotedFrom: ${specPath}`,
      `- acceptedBy: ${params.acceptedBy ?? "unspecified"}`,
      `- acceptedRunId: ${params.runId}`,
      `- promotedAt: ${new Date().toISOString()}`,
      "",
    ].filter((line): line is string => line !== null).join("\n");

    fs.writeFileSync(agentPath, content, "utf8");
    appendJsonl(path.join(stateDir(ctx.cwd, "runs"), `${safeId(params.runId)}.entries.jsonl`), {
      timestamp: new Date().toISOString(),
      runId: params.runId,
      entryType: "dynamic_agent.promoted",
      data: { agentId: id, agentPath, specPath, acceptedBy: params.acceptedBy ?? null },
    });

    return {
      content: [{ type: "text", text: `Dynamic agent promoted: ${id}` }],
      details: { agentId: id, agentPath, specPath },
    };
  },
});

const writePlanTool = defineTool({
  name: "workflow_write_plan",
  label: "Workflow Plan",
  description: "Persist an approved or proposed execution plan for a workflow run.",
  parameters: Type.Object({
    runId: Type.String(),
    planId: Type.Optional(Type.String()),
    status: Type.Union([
      Type.Literal("proposed"),
      Type.Literal("approved"),
      Type.Literal("rejected"),
      Type.Literal("executing"),
      Type.Literal("completed"),
      Type.Literal("failed"),
    ]),
    planType: Type.Optional(Type.String()),
    plan: Type.Record(Type.String(), Type.Unknown()),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const planId = params.planId ?? `${safeId(params.runId)}-plan`;
    const packet = {
      timestamp: new Date().toISOString(),
      runId: params.runId,
      planId,
      status: params.status,
      planType: params.planType ?? null,
      plan: params.plan,
    };
    const filePath = path.join(stateDir(ctx.cwd, "plans"), `${safeId(planId)}.json`);
    ensureDir(path.dirname(filePath));
    fs.writeFileSync(filePath, JSON.stringify(packet, null, 2), "utf8");
    appendJsonl(path.join(stateDir(ctx.cwd, "runs"), `${safeId(params.runId)}.entries.jsonl`), {
      timestamp: packet.timestamp,
      runId: params.runId,
      entryType: "workflow.plan",
      data: { planId, status: params.status, planType: packet.planType },
    });
    return {
      content: [{ type: "text", text: `Workflow plan stored: ${planId} (${params.status})` }],
      details: { plan: packet, filePath },
    };
  },
});

const resolveClientMatterTool = defineTool({
  name: "workflow_resolve_client_matter",
  label: "Resolve Client Matter",
  description: "Resolve client and matter context from launch payload or local workflow fixture data.",
  parameters: Type.Object({
    clientId: Type.Optional(Type.String()),
    clientSlug: Type.Optional(Type.String()),
    clientName: Type.Optional(Type.String()),
    matterId: Type.Optional(Type.String()),
    matterSlug: Type.Optional(Type.String()),
    matterName: Type.Optional(Type.String()),
  }),
  async execute(_toolCallId, params) {
    const clientSlug = params.clientSlug ?? params.clientId ?? "unknown-client";
    const matterSlug = params.matterSlug ?? params.matterId ?? "unknown-matter";
    const details = {
      client: {
        id: params.clientId ?? clientSlug,
        slug: clientSlug,
        name: params.clientName ?? clientSlug,
        clientType: null,
        industry: null,
      },
      matter: {
        id: params.matterId ?? matterSlug,
        slug: matterSlug,
        name: params.matterName ?? matterSlug,
        matterType: null,
        status: null,
        jurisdiction: null,
      },
      warnings: clientSlug === "unknown-client" || matterSlug === "unknown-matter" ? ["Client or matter was not fully identified."] : [],
    };
    return {
      content: [{ type: "text", text: compactJson(details) }],
      details,
    };
  },
});

const listSourceOptionsTool = defineTool({
  name: "workflow_list_source_options",
  label: "List Source Options",
  description: "Return display-safe client, matter, or document picker options for the Apple app.",
  parameters: Type.Object({
    kind: Type.Union([Type.Literal("clients"), Type.Literal("matters"), Type.Literal("documents")]),
    parentId: Type.Optional(Type.String()),
    searchText: Type.Optional(Type.String()),
  }),
  async execute(_toolCallId, params) {
    return {
      content: [{ type: "text", text: `Returned ${params.kind} picker options` }],
      details: {
        kind: params.kind,
        parentId: params.parentId ?? null,
        options: [],
        connectorRequirements: [],
        warnings: ["No Apple local database adapter is connected yet; returned an empty option list."],
      },
    };
  },
});

const resolveDocumentsTool = defineTool({
  name: "workflow_resolve_documents",
  label: "Resolve Documents",
  description: "Resolve user-approved local file paths into stable workflow document references.",
  parameters: Type.Object({
    runId: Type.String(),
    baseDirectory: Type.Optional(Type.String()),
    filePaths: Type.Array(Type.String()),
    clientId: Type.Optional(Type.String()),
    matterId: Type.Optional(Type.String()),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const base = params.baseDirectory ? path.resolve(params.baseDirectory) : ctx.cwd;
    const stagingDirectory = stateDir(ctx.cwd, "documents", safeId(params.runId));
    ensureDir(stagingDirectory);
    const localFiles = params.filePaths.map((inputPath, index) => {
      const resolved = path.resolve(base, inputPath);
      const stat = fs.existsSync(resolved) ? fs.statSync(resolved) : undefined;
      const stagedPath = path.join(stagingDirectory, `${String(index + 1).padStart(3, "0")}-${safeId(path.basename(resolved))}`);
      if (stat?.isFile()) {
        fs.copyFileSync(resolved, stagedPath);
      }
      return {
        id: `doc-${index + 1}`,
        displayName: path.basename(resolved),
        path: stat?.isFile() ? stagedPath : resolved,
        sourceUri: `file://${resolved}`,
        stagedFrom: resolved,
        clientId: params.clientId ?? null,
        matterId: params.matterId ?? null,
        mimeType: null,
        sizeBytes: stat?.isFile() ? stat.size : null,
        exists: Boolean(stat?.isFile()),
      };
    });
    return {
      content: [{ type: "text", text: compactJson({ localFiles, warnings: localFiles.filter((file) => !file.exists).map((file) => `Missing file: ${file.path}`) }) }],
      details: { localFiles, warnings: localFiles.filter((file) => !file.exists).map((file) => `Missing file: ${file.path}`) },
    };
  },
});

const extractTextTool = defineTool({
  name: "workflow_extract_text",
  label: "Extract Text",
  description: "Extract text from local document references when the file is directly readable as text.",
  parameters: Type.Object({
    documents: Type.Array(Type.Object({
      id: Type.String(),
      displayName: Type.String(),
      path: Type.String(),
    })),
  }),
  async execute(_toolCallId, params) {
    const documentsText = [];
    const warnings = [];
    for (const doc of params.documents) {
      const resolvedPath = localPath(doc.path);
      const ext = path.extname(resolvedPath).toLowerCase();
      if (!fs.existsSync(resolvedPath)) {
        warnings.push(`Missing file: ${resolvedPath}`);
        continue;
      }
      if (![".txt", ".md", ".markdown", ".json", ".csv"].includes(ext)) {
        warnings.push(`Extractor needs a richer parser for ${doc.displayName} (${ext || "no extension"})`);
        continue;
      }
      documentsText.push({
        documentId: doc.id,
        displayName: doc.displayName,
        text: readTextFile(resolvedPath),
        anchors: [],
        extractionMethod: ext === ".json" ? "structured" : "text",
      });
    }
    return {
      content: [{ type: "text", text: compactJson({ documentsText, warnings }) }],
      details: { documentsText, warnings },
    };
  },
});

const readFileTool = defineTool({
  name: "workflow_read_file",
  label: "Read Workflow File",
  description: "Read an approved local workflow document file. Prefer workflow_extract_text for document extraction.",
  parameters: Type.Object({
    path: Type.String(),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    let resolvedPath: string;
    try {
      resolvedPath = approvedLocalWorkflowPath(ctx.cwd, params.path);
    } catch (error) {
      return {
        content: [{ type: "text", text: error instanceof Error ? error.message : "Path is not approved." }],
        details: { path: params.path },
        isError: true,
      };
    }
    if (!fs.existsSync(resolvedPath) || !fs.statSync(resolvedPath).isFile()) {
      return {
        content: [{ type: "text", text: `Missing file: ${resolvedPath}` }],
        details: { path: resolvedPath },
        isError: true,
      };
    }
    const text = readTextFile(resolvedPath);
    const details = { path: resolvedPath, displayName: path.basename(resolvedPath), text };
    return {
      content: [{ type: "text", text: compactJson(details) }],
      details,
    };
  },
});

const requestHumanReviewTool = defineTool({
  name: "workflow_request_human_review",
  label: "Request Human Review",
  description: "Create a durable human review request for the Apple app and pause finalization until a decision exists.",
  parameters: Type.Object({
    runId: Type.String(),
    workflowId: Type.String(),
    reviewId: Type.Optional(Type.String()),
    title: Type.String(),
    payload: Type.Record(Type.String(), Type.Unknown()),
    allowedDecisions: Type.Array(Type.String()),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const reviewId = params.reviewId ?? `${safeId(params.runId)}-review`;
    const review = {
      timestamp: new Date().toISOString(),
      status: "awaiting_review",
      reviewId,
      runId: params.runId,
      workflowId: params.workflowId,
      title: params.title,
      payload: params.payload,
      allowedDecisions: params.allowedDecisions,
    };
    const filePath = path.join(stateDir(ctx.cwd, "human-reviews"), `${safeId(reviewId)}.json`);
    ensureDir(path.dirname(filePath));
    fs.writeFileSync(filePath, JSON.stringify(review, null, 2), "utf8");
    const event = {
      timestamp: review.timestamp,
      runId: params.runId,
      workflowId: params.workflowId,
      type: "human_review.requested",
      status: "awaiting_review",
      summary: params.title,
      raw: { reviewId, filePath },
    };
    appendJsonl(path.join(stateDir(ctx.cwd, "events"), `${safeId(params.runId)}.jsonl`), event);
    appendJsonl(path.join(stateDir(ctx.cwd, "runs"), `${safeId(params.runId)}.entries.jsonl`), {
      timestamp: review.timestamp,
      runId: params.runId,
      entryType: "human_review.requested",
      data: { reviewId, title: params.title, allowedDecisions: params.allowedDecisions, filePath },
    });
    updateRunStatus(ctx.cwd, params.runId, {
      workflowId: params.workflowId,
      status: "awaiting_review",
      pendingHumanReview: { reviewId, title: params.title, allowedDecisions: params.allowedDecisions, filePath },
      latestEvent: event,
      latestEventType: "human_review.requested",
      latestSummary: params.title,
    });
    return {
      content: [{ type: "text", text: `Human review requested: ${reviewId}` }],
      details: { review, filePath },
    };
  },
});

const waitForHumanReviewTool = defineTool({
  name: "workflow_wait_for_human_review",
  label: "Wait Human Review",
  description: "Read a human review decision written by the Apple app.",
  parameters: Type.Object({
    reviewId: Type.String(),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const decisionPath = path.join(stateDir(ctx.cwd, "human-reviews"), `${safeId(params.reviewId)}.decision.json`);
    if (!fs.existsSync(decisionPath)) {
      return {
        content: [{ type: "text", text: `Human review decision is not ready: ${params.reviewId}` }],
        details: { reviewId: params.reviewId, status: "awaiting_review", decisionPath },
        isError: true,
      };
    }
    const decision = JSON.parse(fs.readFileSync(decisionPath, "utf8"));
    const reviewPath = path.join(stateDir(ctx.cwd, "human-reviews"), `${safeId(params.reviewId)}.json`);
    const review = readJsonObject(reviewPath);
    const runId = typeof review.runId === "string" ? review.runId : typeof decision.runId === "string" ? decision.runId : params.reviewId;
    const workflowId = typeof review.workflowId === "string" ? review.workflowId : typeof decision.workflowId === "string" ? decision.workflowId : undefined;
    const event = {
      timestamp: new Date().toISOString(),
      runId,
      workflowId,
      type: "human_review.completed",
      status: "running",
      reviewId: params.reviewId,
      summary: `Human review completed: ${params.reviewId}`,
      raw: { decisionPath, decision },
    };
    appendWorkflowEvent(ctx.cwd, event);
    appendWorkflowRunEntry(ctx.cwd, runId, "human_review.completed", {
      reviewId: params.reviewId,
      decision,
      decisionPath,
    });
    updateRunStatus(ctx.cwd, runId, {
      workflowId,
      status: "running",
      pendingHumanReview: null,
      latestHumanReviewDecision: { reviewId: params.reviewId, decision, decisionPath },
      latestEvent: event,
      latestEventType: "human_review.completed",
      latestSummary: `Human review completed: ${params.reviewId}`,
    });
    return {
      content: [{ type: "text", text: `Human review decision loaded: ${params.reviewId}` }],
      details: { reviewId: params.reviewId, status: "completed", decision },
    };
  },
});

const writeArtifactTool = defineTool({
  name: "workflow_write_artifact",
  label: "Write Artifact",
  description: "Write a workflow artifact into app-owned local runtime state.",
  parameters: Type.Object({
    runId: Type.String(),
    artifactId: Type.String(),
    filename: Type.String(),
    content: Type.String(),
    contentType: Type.Optional(Type.String()),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const artifactDir = stateDir(ctx.cwd, "artifacts", safeId(params.runId));
    ensureDir(artifactDir);
    const filePath = path.join(artifactDir, path.basename(params.filename));
    fs.writeFileSync(filePath, params.content, "utf8");
    const statusPath = path.join(stateDir(ctx.cwd, "runs"), `${safeId(params.runId)}.status.json`);
    const existingStatus = readJsonObject(statusPath);
    const artifact = {
      id: params.artifactId,
      type: params.contentType ?? "text/plain",
      uri: filePath,
      title: params.filename,
    };
    updateRunStatus(ctx.cwd, params.runId, {
      latestArtifact: artifact,
      artifacts: appendStatusArray(existingStatus.artifacts, artifact),
    });
    appendWorkflowEvent(ctx.cwd, {
      timestamp: new Date().toISOString(),
      runId: params.runId,
      workflowId: existingStatus.workflowId,
      type: "output.written",
      status: "running",
      summary: `Artifact written: ${params.filename}`,
      outputs: [artifact],
      raw: artifact,
    });
    return {
      content: [{ type: "text", text: `Artifact written: ${params.filename}` }],
      details: artifact,
    };
  },
});

const structuredOutputTool = defineTool({
  name: "workflow_structured_output",
  label: "Workflow Structured Output",
  description: "Return the final machine-readable workflow output and terminate the Pi turn.",
  parameters: Type.Object({
    runId: Type.String(),
    workflowId: Type.String(),
    status: Type.String(),
    outputs: Type.Record(Type.String(), Type.Unknown()),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    updateRunStatus(ctx.cwd, params.runId, {
      workflowId: params.workflowId,
      status: params.status,
      outputs: params.outputs,
    });
    if (params.status === "completed") {
      appendWorkflowEvent(ctx.cwd, {
        timestamp: new Date().toISOString(),
        runId: params.runId,
        workflowId: params.workflowId,
        type: "workflow.completed",
        status: "completed",
        summary: `Workflow completed: ${params.workflowId}`,
        raw: { outputs: params.outputs },
      });
    }
    return {
      content: [{ type: "text", text: `Workflow output captured: ${params.workflowId} ${params.status}` }],
      details: params,
      terminate: true,
    };
  },
});

const publishFinalPacketTool = defineTool({
  name: "workflow_publish_final_packet",
  label: "Publish Final Output Packet",
  description: "Validate and publish a durable final-output packet created in app-owned runtime state.",
  parameters: Type.Object({
    runId: Type.String(),
    packetPath: Type.String(),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const packetsRoot = stateDir(ctx.cwd, "output-packets");
    const packetPath = path.resolve(params.packetPath);
    if (packetPath !== packetsRoot && !packetPath.startsWith(`${packetsRoot}${path.sep}`)) {
      return {
        content: [{ type: "text", text: "Final output packet must be inside app-owned runtime state." }],
        details: { packetPath, packetsRoot },
        isError: true,
      };
    }

    let packet: Record<string, unknown>;
    try {
      packet = JSON.parse(fs.readFileSync(packetPath, "utf8"));
    } catch (error) {
      return {
        content: [{ type: "text", text: error instanceof Error ? error.message : "Unable to read final output packet." }],
        details: { packetPath },
        isError: true,
      };
    }

    const artifactInput = packet.artifact as Record<string, unknown> | undefined;
    const structured = packet.structured as Record<string, unknown> | undefined;
    const outputs = structured?.outputs as Record<string, unknown> | undefined;
    const report = typeof artifactInput?.content === "string" ? artifactInput.content : "";
    const filename = typeof artifactInput?.filename === "string" ? artifactInput.filename : "";
    const artifactId = typeof artifactInput?.artifactId === "string" ? artifactInput.artifactId : "";
    const workflowId = typeof structured?.workflowId === "string" ? structured.workflowId : "";
    const reviewCount = Number(outputs?.validation && typeof outputs.validation === "object"
      ? (outputs.validation as Record<string, unknown>).preservedReviewItemCount ?? 0
      : 0);

    if (packet.runId !== params.runId || !report || !filename || !artifactId || !workflowId || reviewCount < 1) {
      return {
        content: [{ type: "text", text: "Final output packet is incomplete or does not match this run." }],
        details: { packetPath, packetRunId: packet.runId, workflowId, reportLength: report.length, reviewCount },
        isError: true,
      };
    }

    const artifactDir = stateDir(ctx.cwd, "artifacts", safeId(params.runId));
    ensureDir(artifactDir);
    const filePath = path.join(artifactDir, path.basename(filename));
    fs.writeFileSync(filePath, report, "utf8");
    const statusPath = path.join(stateDir(ctx.cwd, "runs"), `${safeId(params.runId)}.status.json`);
    const existingStatus = readJsonObject(statusPath);
    const artifact = {
      id: artifactId,
      type: typeof artifactInput?.contentType === "string" ? artifactInput.contentType : "text/markdown",
      uri: filePath,
      title: filename,
    };
    const completedOutputs: Record<string, unknown> = { ...(outputs ?? {}), response: report };

    updateRunStatus(ctx.cwd, params.runId, {
      workflowId,
      status: "completed",
      latestArtifact: artifact,
      artifacts: appendStatusArray(existingStatus.artifacts, artifact),
      outputs: completedOutputs,
    });
    appendWorkflowRunEntry(ctx.cwd, params.runId, "output.final_packet", {
      packetPath,
      artifact,
      preservedReviewItemCount: reviewCount,
      validation: completedOutputs.validation ?? null,
    });

    const timestamp = new Date().toISOString();
    appendWorkflowEvent(ctx.cwd, {
      timestamp,
      runId: params.runId,
      workflowId,
      type: "output.written",
      status: "running",
      summary: `Final report written with ${reviewCount} preserved review item(s).`,
      outputs: [artifact],
      raw: { artifact, packetPath },
    });
    appendWorkflowEvent(ctx.cwd, {
      timestamp,
      runId: params.runId,
      workflowId,
      type: "output.validated",
      status: "completed",
      summary: `Final output packet validated: ${reviewCount} review item(s) preserved.`,
      raw: { validation: completedOutputs.validation ?? null, reviewCount },
    });
    appendWorkflowEvent(ctx.cwd, {
      timestamp,
      runId: params.runId,
      workflowId,
      type: "work_unit.completed",
      status: "completed",
      stageId: "report",
      graphId: "synthesis_review_and_report",
      subgraphId: "report_generation",
      workUnitId: "document_onboarding.output",
      teamId: "output-team",
      summary: "Final output packet completed.",
    });
    appendWorkflowEvent(ctx.cwd, {
      timestamp,
      runId: params.runId,
      workflowId,
      type: "team.completed",
      status: "completed",
      stageId: "report",
      graphId: "synthesis_review_and_report",
      subgraphId: "report_generation",
      workUnitId: "document_onboarding.output",
      teamId: "output-team",
      summary: "Output team completed final packet publication.",
    });
    appendWorkflowEvent(ctx.cwd, {
      timestamp,
      runId: params.runId,
      workflowId,
      type: "workflow.completed",
      status: "completed",
      summary: `Workflow completed: ${workflowId}`,
      raw: { outputs: completedOutputs },
    });
    return {
      content: [{ type: "text", text: `Final packet published: ${filename}` }],
      details: { artifact, packetPath, reviewCount },
      terminate: true,
    };
  },
});

export default function workflowTools(pi: ExtensionAPI) {
  pi.registerTool(emitEventTool);
  pi.registerTool(appendRunEntryTool);
  pi.registerTool(callAgentTool);
  pi.registerTool(runTeamTool);
  pi.registerTool(callDynamicAgentTool);
  pi.registerTool(promoteDynamicAgentTool);
  pi.registerTool(writePlanTool);
  pi.registerTool(resolveClientMatterTool);
  pi.registerTool(listSourceOptionsTool);
  pi.registerTool(resolveDocumentsTool);
  pi.registerTool(extractTextTool);
  pi.registerTool(readFileTool);
  pi.registerTool(requestHumanReviewTool);
  pi.registerTool(waitForHumanReviewTool);
  pi.registerTool(writeArtifactTool);
  pi.registerTool(structuredOutputTool);
  pi.registerTool(publishFinalPacketTool);
}
