#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const [runId, stateDir, mode] = process.argv.slice(2);
if (!runId || !stateDir) {
  throw new Error("Usage: build-document-onboarding-final-report.js <run-id> <state-dir>");
}

const readJson = (filePath) => JSON.parse(fs.readFileSync(filePath, "utf8"));
const readJsonl = (filePath) => fs.existsSync(filePath)
  ? fs.readFileSync(filePath, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line))
  : [];

function parseJsonPacket(value) {
  if (typeof value !== "string") return null;
  const fenced = value.match(/```(?:json)?\s*([\s\S]*?)```/i)?.[1] ?? value;
  try {
    return JSON.parse(fenced.trim());
  } catch {
    return null;
  }
}

function entryPacket(entries, entryType) {
  const entry = [...entries].reverse().find((item) => item.entryType === entryType);
  return parseJsonPacket(entry?.data?.output);
}

function entryOutput(entries, entryType) {
  const entry = [...entries].reverse().find((item) => item.entryType === entryType);
  return typeof entry?.data?.output === "string" ? entry.data.output.trim() : "";
}

function markdown(value) {
  return String(value ?? "").replace(/\r\n/g, "\n").trim();
}

function bulletList(values, empty = "No items were recorded.") {
  const items = (Array.isArray(values) ? values : []).map((value) => {
    if (value && typeof value === "object") {
      const item = value;
      const description = markdown(item.description ?? item.action ?? item.title ?? item.name ?? item.risk ?? item.issue);
      const priority = markdown(item.priority ?? item.severity);
      return priority && description ? `**${priority}:** ${description}` : description;
    }
    return markdown(value);
  }).filter(Boolean);
  return items.length ? items.map((item) => `- ${item}`).join("\n") : `- ${empty}`;
}

function reviewSegments(packet) {
  const raw = packet?.reviewPacket ?? packet ?? {};
  const segments = raw.segments ?? raw.reviewSegments ?? [];
  return Array.isArray(segments) ? segments.map((segment, index) => ({
    id: markdown(segment.segmentId ?? segment.id ?? `review-${index + 1}`),
    title: markdown(segment.title ?? segment.focusArea ?? segment.focus ?? `Review item ${index + 1}`),
    description: markdown(segment.description ?? segment.question),
    proposedPosition: markdown(segment.proposedPosition ?? segment.keyQuestion),
    whyItMatters: markdown(segment.whyItMatters ?? segment.impactIfUnaddressed),
    requestedClarification: markdown(segment.requestedClarification ?? segment.consequenceOfDecision),
    citations: Array.isArray(segment.supportingCitations) ? segment.supportingCitations : [],
    decisions: Array.isArray(segment.availableDecisions) ? segment.availableDecisions : [],
  })) : [];
}

const runRecordPath = path.join(stateDir, "runs", `${runId}.json`);
const statusPath = path.join(stateDir, "runs", `${runId}.status.json`);
const entriesPath = path.join(stateDir, "runs", `${runId}.entries.jsonl`);
if (!fs.existsSync(statusPath) || !fs.existsSync(entriesPath)) {
  throw new Error(`Run ${runId} has no durable runtime state.`);
}

const status = readJson(statusPath);
const runRecord = fs.existsSync(runRecordPath) ? readJson(runRecordPath) : {};
const entries = readJsonl(entriesPath);
const reviewPacket = entryPacket(entries, "human_review.payload");
const metadataPacket = entryPacket(entries, "metadata.packet");
const synthesisPacket = entryPacket(entries, "synthesis.packet");
const reportWriterOutput = entryOutput(entries, "output.report");
const segments = reviewSegments(reviewPacket);
const completedReviewEvent = [...entries].reverse().find((item) => item.entryType === "human_review.completed");
const savedReview = runRecord.humanReview ?? {};
const decision = status.latestHumanReviewDecision?.decision ?? (
  savedReview.status === "approved"
    ? {
      decision: "approve",
      reviewer: "Authorized reviewer",
      timestamp: completedReviewEvent?.timestamp,
      edits: [],
    }
    : {}
);

if (!segments.length) {
  throw new Error(`Run ${runId} has no human-review segments to preserve in the final report.`);
}
if (decision.decision !== "approve") {
  throw new Error(`Run ${runId} has not received final human approval.`);
}

const metadata = metadataPacket?.documentsMetadata ?? [];
const documents = Array.isArray(metadata) ? metadata.map((document, index) => {
  const type = document.documentType?.typeCandidates?.[0] ?? document.documentType ?? "Document";
  const source = document.sourceRefs?.[0] ?? document.documentId ?? `document-${index + 1}`;
  return `${source} (${type})`;
}) : [];
const synthesis = synthesisPacket?.synthesis ?? synthesisPacket ?? {};
const risks = synthesis.riskMatrix ?? [];
const actions = synthesis.recommendedActions ?? [];
const editNotes = Array.isArray(decision.edits) ? decision.edits : [];
const reportWriterNarrative = reportWriterOutput.length >= 300 &&
  !reportWriterOutput.startsWith("<antml:") &&
  !reportWriterOutput.startsWith("Read ")
  ? reportWriterOutput.replace(/^```(?:markdown)?\s*/i, "").replace(/\s*```$/, "")
  : "";

const reviewMarkdown = segments.map((segment, index) => {
  const options = segment.decisions.map((item) => {
    const choice = markdown(item.choice ?? item.option);
    const instruction = markdown(item.instruction);
    return choice || instruction ? `  - **${choice || "Option"}:** ${instruction}` : null;
  }).filter(Boolean).join("\n");
  const associatedEdits = editNotes.filter((edit) => edit.segmentId === segment.id || edit.segmentId.includes(segment.id));
  return [
    `### ${index + 1}. ${segment.title}`,
    segment.description ? `**Issue:** ${segment.description}` : null,
    segment.proposedPosition ? `**Proposed position / decision question:** ${segment.proposedPosition}` : null,
    segment.whyItMatters ? `**Why it matters:** ${segment.whyItMatters}` : null,
    segment.citations.length ? `**Evidence:** ${segment.citations.join(", ")}` : null,
    segment.requestedClarification ? `**Required clarification or consequence:** ${segment.requestedClarification}` : null,
    options ? `**Available decisions:**\n${options}` : null,
    associatedEdits.length ? `**Approved reviewer direction:** ${associatedEdits.map((edit) => markdown(edit.note)).filter(Boolean).join("; ")}` : null,
    "**Recorded disposition:** Approved for the final packet.",
  ].filter(Boolean).join("\n\n");
}).join("\n\n");

const riskMarkdown = Array.isArray(risks) && risks.length
  ? risks.map((risk) => `- **${markdown(risk.severity ?? "review")}: ${markdown(risk.risk ?? risk.issue)}**${risk.citations?.length ? ` (${risk.citations.join(", ")})` : ""}`).join("\n")
  : "- Material risks are documented in the attorney review below.";

const report = [
  "# Document Onboarding Report",
  "## Executive Summary",
  markdown(synthesis.executiveSummary) || `${status.client?.name ?? "The client"} completed document onboarding for ${status.matter?.name ?? "this matter"}. The final packet preserves the attorney-reviewed conditions below.`,
  "## Scope and Limitations",
  "This report records workflow findings and the approved human-review record. It is not a substitute for legal advice, and it does not resolve facts that the review identifies as requiring confirmation or negotiation.",
  "## Client and Matter",
  `- **Client:** ${status.client?.name ?? "Not recorded"}`,
  `- **Matter:** ${status.matter?.name ?? "Not recorded"}`,
  "- **Workflow:** Document Onboarding",
  "## Documents Reviewed",
  bulletList(documents, "Document metadata was not available in the durable packet."),
  "## Workflow Findings",
  riskMarkdown,
  reportWriterNarrative ? "## Attorney-Ready Assessment" : null,
  reportWriterNarrative || null,
  "## Attorney Review Decisions",
  `**Reviewer:** ${markdown(decision.reviewer) || "Authorized reviewer"}  `,
  `**Decision:** Approved  `,
  `**Recorded:** ${markdown(decision.timestamp) || "Recorded in workflow state"}`,
  reviewMarkdown,
  "## Recommended Actions",
  bulletList(actions, "Complete the approved review directions above before executing the underlying agreement."),
  "## Traceability",
  `- Run: ${runId}`,
  `- Review: ${status.latestHumanReviewDecision?.reviewId ?? "Not recorded"}`,
  `- Review items preserved: ${segments.length}`,
].join("\n\n") + "\n";

const missingReviewItems = segments.filter((segment) => !report.includes(segment.title)).map((segment) => segment.id);
if (missingReviewItems.length) {
  throw new Error(`Final report omitted human-review items: ${missingReviewItems.join(", ")}`);
}

const packet = {
  runId,
  workflowId: "legal.document-onboarding",
  report,
  artifact: {
    runId,
    artifactId: "document-onboarding-report",
    filename: "document-onboarding-report.md",
    contentType: "text/markdown",
    content: report,
  },
  structured: {
    runId,
    workflowId: "legal.document-onboarding",
    status: "completed",
    outputs: {
      response: report,
      artifacts: [{ id: "document-onboarding-report", filename: "document-onboarding-report.md", contentType: "text/markdown" }],
      displayEnvelope: {
        kind: "legal.document-onboarding.report",
        title: "Document Onboarding Report",
        summary: `Final packet preserves ${segments.length} approved attorney-review item${segments.length === 1 ? "" : "s"}.`,
      },
      validation: { status: "pass", requiredFixes: [], preservedReviewItemCount: segments.length },
    },
  },
  reportWriterBrief: {
    reviewItems: segments,
    decision,
    synthesis,
    instruction: "Write a concise attorney-ready assessment that adds context but does not omit, soften, or contradict any item in the canonical final packet.",
  },
};

const packetPath = path.join(stateDir, "output-packets", `${runId}.document-onboarding-final.json`);
fs.mkdirSync(path.dirname(packetPath), { recursive: true });
fs.writeFileSync(packetPath, JSON.stringify(packet, null, 2));

if (mode === "--publish") {
  const artifactDir = path.join(stateDir, "artifacts", runId);
  const artifactPath = path.join(artifactDir, packet.artifact.filename);
  const artifact = {
    id: packet.artifact.artifactId,
    type: packet.artifact.contentType,
    uri: artifactPath,
    title: packet.artifact.filename,
  };
  fs.mkdirSync(artifactDir, { recursive: true });
  fs.writeFileSync(artifactPath, packet.artifact.content, "utf8");

  const existingArtifacts = Array.isArray(status.artifacts) ? status.artifacts : [];
  status.status = "completed";
  status.latestArtifact = artifact;
  status.artifacts = [...existingArtifacts.filter((item) => item?.id !== artifact.id), artifact];
  status.outputs = packet.structured.outputs;
  status.updatedAt = new Date().toISOString();
  fs.writeFileSync(statusPath, JSON.stringify(status, null, 2));

  const timestamp = new Date().toISOString();
  const append = (filePath, value) => fs.appendFileSync(filePath, `${JSON.stringify(value)}\n`, "utf8");
  append(entriesPath, {
    timestamp,
    runId,
    entryType: "output.final_packet",
    data: {
      packetPath,
      artifact,
      preservedReviewItemCount: packet.structured.outputs.validation.preservedReviewItemCount,
      validation: packet.structured.outputs.validation,
    },
  });
  const eventsPath = path.join(stateDir, "events", `${runId}.jsonl`);
  const baseEvent = {
    timestamp,
    runId,
    workflowId: packet.workflowId,
    stageId: "report",
    graphId: "synthesis_review_and_report",
    subgraphId: "report_generation",
    workUnitId: "document_onboarding.output",
    teamId: "output-team",
  };
  append(eventsPath, {
    ...baseEvent,
    type: "output.written",
    status: "running",
    summary: `Final report written with ${packet.structured.outputs.validation.preservedReviewItemCount} preserved review item(s).`,
    outputs: [artifact],
  });
  append(eventsPath, {
    ...baseEvent,
    type: "output.validated",
    status: "completed",
    summary: `Final packet validated: ${packet.structured.outputs.validation.preservedReviewItemCount} review item(s) preserved.`,
  });
  append(eventsPath, { ...baseEvent, type: "work_unit.completed", status: "completed", summary: "Final output packet completed." });
  append(eventsPath, { ...baseEvent, type: "team.completed", status: "completed", summary: "Output team completed final packet publication." });
  append(eventsPath, { ...baseEvent, type: "workflow.completed", status: "completed", summary: `Workflow completed: ${packet.workflowId}` });
}

process.stdout.write(packetPath);
