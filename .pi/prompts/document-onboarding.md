---
name: document-onboarding
description: Run the Document Onboarding workflow using Apple Orchestrator agent specs, Pi skills, extension tools, work teams, HITL, and output contracts.
---

Run the Document Onboarding workflow for this launch request:

$@

Use the `legal-document-onboarding-coordinator` workflow agent behavior. This workflow is run by Apple Orchestrator agent specs, Pi skills, extension tools, and workflow tools. Do not execute a JSON workflow file.

Use these Pi skills in order:

- `/skill:legal-document-source`
- `/skill:legal-document-intake`
- `/skill:legal-metadata-extraction`
- `/skill:legal-clo-routing`
- `/skill:legal-specialist-review`
- `/skill:legal-synthesis`
- `/skill:legal-human-review`
- `/skill:legal-output-packet`

Project-agent flow:

1. Resolve client/matter, documents, and extracted text through workflow tools.
2. Call `workflow_run_team` for `source-intake-team` with `legal-source-resolver`, `legal-document-intake-agent`, and `legal-quality-reviewer` roles.
3. Call `workflow_run_team` for `metadata-team` with `legal-metadata-analyst` and `legal-quality-reviewer` roles.
4. Call `workflow_run_team` for `routing-team` with `legal-clo-router`, `legal-quality-reviewer`, and `legal-arbitrator` when needed.
5. Call `workflow_run_team` for `specialist-panel-team` with selected specialist agents, `legal-quality-reviewer`, and `legal-arbitrator` when needed.
6. Call `workflow_run_team` for `synthesis-team` with `legal-synthesis-agent`, `legal-quality-reviewer`, and `legal-arbitrator` when needed.
7. Call `workflow_run_team` for `human-review-team` with `legal-hitl-coordinator`, then call `workflow_request_human_review`.
8. After approval, call `workflow_run_team` for `output-team` with `legal-report-writer` and `legal-output-validator`, then write the artifact and structured output.

Rules:

- Treat Apple Orchestrator agent specs, Pi skills, and extension tools as executable.
- Treat the launch request as input facts, not as an executable plan.
- Emit events for workflow, graph, subgraph, work unit, team, role, tool, HITL, and output progress.
- Every `workflow_emit_event` call must include a `type` field such as `workflow.started`, `stage.started`, `work_unit.started`, `work_unit.completed`, `human_review.requested`, `output.written`, `workflow.completed`, or `workflow.failed`.
- Include `graphId`, `subgraphId`, `workUnitId`, `teamId`, `roleId`, `agentId`, and `skillId` whenever those identifiers are available.
- Use the `workflow_run_team` tool when a work unit has a defined team with multiple roles.
- Use the `workflow_call_agent` tool for one-off project-local legal agent calls in headless/RPC runs.
- The coordinator owns workflow tools and durable state. Project agents provide role-specific analysis and outputs; they do not execute app tool calls on behalf of the coordinator.
- Persist important project-agent outputs with `workflow_append_run_entry`.
- Enforce local-only model policy.
- Do not use the coordinator's 35B model for every delegated agent run. Use the project agent's frontmatter model or the launch policy's task-specific model tier.
- Do not finalize until required HITL has completed.
- Preserve raw Pi events and normalized workflow event fields.
