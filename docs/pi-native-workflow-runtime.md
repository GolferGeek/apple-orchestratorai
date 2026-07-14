# Pi-Native Workflow Runtime

This app should use Pi as the workflow runtime, not as a subprocess hidden behind a separate homegrown JSON runner.

The executable layer is Pi-native:

- skills are Agent Skills packages in `.pi/skills/**/SKILL.md`
- tools are Pi extension tools registered through `.pi/extensions`
- workflow prompts are Pi prompt templates in `.pi/prompts/*.md`
- sessions and events come from Pi `AgentSession` / RPC event streams
- workflow observability is normalized from Pi events plus app workflow entries

Apple Orchestrator also defines project-local agent specs in `.pi/agents/*.md`. Pi does not auto-discover this folder. These files are an Apple Orchestrator convention loaded by the workflow extension through `workflow_call_agent`.

JSON files may remain as catalog metadata, examples, launch fixtures, or display contracts for the Apple app. They are not execution plans for Pi. The executable workflow is a workflow agent spec plus Pi skills, Apple Orchestrator agent specs, extension tools, and Pi sessions.

## Workflow Agents

Each productized workflow should have a specific workflow agent. The workflow agent is the executable owner of the workflow. It defines the workflow's phases, graphs, subgraphs, work units, work teams, agent roles, HITL checkpoints, outputs, and stop/resume behavior.

The workflow agent may break itself down internally:

- workflow-specific phase skills for behavior unique to that workflow
- workflow-specific sub-agents for bounded phases or work units
- shared agents and shared skills only when the capability is reusable across workflows
- shared work teams only when the team pattern is reusable across workflows

This lets the workflow stay agentic without becoming vague. A phase is not a JSON step to execute; it is a bounded skill/sub-agent contract owned by the workflow agent.

The boundary rule is:

- If a capability is particular to one workflow, keep it inside that workflow agent or a workflow-specific skill/sub-agent.
- If a capability is broadly reusable, place it in shared legal, shared workflow, or shared runtime agents/skills.
- If a new workflow needs a different shape, create or adapt a workflow agent instead of adding conditionals to a generic runner.

## Product Hierarchy

The app-level hierarchy is:

```text
workflow
  graph
    subgraph
      work unit
        work team
          agent role
            Pi agent
            Pi skills
            Pi tools
            outputs
```

Pi is responsible for the executable portion from work team downward. The Apple app is responsible for launch payloads, permissions, UI, durable run state, human review surfaces, and displaying normalized output.

The coordinator owns the app/tool boundary. It calls workflow tools to resolve source data, extract text, request HITL, and write artifacts. Project agents receive coordinator-provided facts and produce role-specific analysis; they do not rediscover source context unless the coordinator explicitly asks for verification.

## Pi Mapping

| Product concept | Pi-native implementation |
| --- | --- |
| Agent | Apple Orchestrator agent spec in `.pi/agents/<agent>.md`, loaded by the workflow extension into an isolated Pi child process |
| Skill | `.pi/skills/<skill>/SKILL.md` using Agent Skills frontmatter and instructions |
| Tool | Pi extension tool registered by `pi.registerTool()` |
| Workflow | A specific workflow agent spec, optionally launched by `.pi/prompts/<workflow>.md` |
| Graph/subgraph | Bounded phase/sub-agent contracts owned by the workflow agent and emitted as events |
| Work unit | A typed Pi tool call or project-agent task with one required output contract |
| Work team | A workflow-agent task that invokes named Apple Orchestrator agent specs in sequence, parallel, or arbitration pattern |
| HITL | Pi custom tool/UI request plus durable custom session entry; app normalizes to `human_review.requested` |
| Event | Pi `AgentSessionEvent` / RPC event normalized to `workflow-event.v0` |
| Output | Structured-output tool result, artifact write, or display envelope |

## Native Pi Events We Rely On

Pi emits these core events through `AgentSession` and RPC:

- `agent_start`
- `agent_end`
- `turn_start`
- `turn_end`
- `message_start`
- `message_update`
- `message_end`
- `tool_execution_start`
- `tool_execution_update`
- `tool_execution_end`
- `queue_update`
- `entry_appended`
- `compaction_start`
- `compaction_end`
- `auto_retry_start`
- `auto_retry_end`
- `session_info_changed`

Extensions also expose lifecycle hooks and tool hooks:

- `session_start`
- `session_shutdown`
- `resources_discover`
- `before_agent_start`
- `tool_call`
- `tool_result`
- `message_end`
- `input`
- `session_before_compact`
- `session_compact`

The app should preserve raw Pi events and write normalized workflow events with correlation fields:

- `runId`
- `workflowId`
- `graphId`
- `subgraphId`
- `workUnitId`
- `teamId`
- `roleId`
- `agentId`
- `skillId`
- `toolCallId`
- `rawPiSessionId`
- `rawPiCommandId`

## Document Onboarding Runtime Shape

Document onboarding should be built as a Pi workflow agent with bounded workflow phases and several specialized agents.

## Model Routing

The coordinator may use a deep model, but graph, work-unit, and agent runs should not all inherit that model. The default local model tiers are:

| Tier | Model | Intended use |
| --- | --- | --- |
| `fast` | `gemma4:e2b-mlx` | picker support, smoke tests, tiny classification |
| `standard` | `gemma4:e4b-mlx` | source resolution, intake packets, HITL packet shaping, bounded validation, routing, first-pass specialist review, quality review, lightweight dynamic agents |
| `reasoning` | `qwen3.6:27b-mlx` | escalated specialist analysis, escalated quality review, report drafting |
| `deep` | `qwen3.6:35b-mlx` | workflow coordination, discovery planning, arbitration, synthesis, unusually hard reasoning |

Project agents declare their default model in frontmatter. `workflow_call_agent` and `workflow_call_dynamic_agent` ignore model overrides unless the call includes `modelOverrideReason`. Overrides should only come from an approved plan or launch policy, and escalation reasons should be recorded in run state.

### Coordinator

`legal-document-onboarding-coordinator`

This is the Document Onboarding workflow agent. It accepts launch facts, defines the workflow phases, invokes skills and Apple Orchestrator agent specs or workflow-specific sub-agents, enforces model policy, emits status entries, and refuses to finalize without HITL approval. It does not execute a JSON workflow file.

The coordinator's minimum sequence is:

1. Resolve client, matter, selected documents, and extracted text through workflow tools.
2. Run `source-intake-team` through `workflow_run_team`, using `legal-source-resolver`, `legal-document-intake-agent`, and `legal-quality-reviewer`.
3. Run `metadata-team` through `workflow_run_team`, using `legal-metadata-analyst` and `legal-quality-reviewer`.
4. Run `routing-team` through `workflow_run_team`, using `legal-clo-router`, `legal-quality-reviewer`, and `legal-arbitrator` when needed.
5. Run `specialist-panel-team` through `workflow_run_team`, using selected specialist agents, `legal-quality-reviewer`, and `legal-arbitrator` when needed.
6. Run `synthesis-team` through `workflow_run_team`, using `legal-synthesis-agent`, `legal-quality-reviewer`, and `legal-arbitrator` when needed.
7. Run `human-review-team` through `workflow_run_team`, then call `workflow_request_human_review` and pause finalization.
8. After approval, run `output-team` through `workflow_run_team`, then write artifacts and structured output.

### Source And Intake Agents

`legal-source-resolver`

Finds clients, matters, and documents through Apple local storage or approved connector tools. The Swift frontend never queries external legal systems directly.

`legal-document-intake-agent`

Resolves file paths, verifies approved roots, extracts text, invokes OCR or DOCX tracked-change extraction when needed, and creates stable document references.

### Metadata And Routing Agents

`legal-metadata-analyst`

Extracts document type, parties, sections, signatures, dates, deadlines, obligations, sensitivity flags, and confidence values.

`legal-clo-router`

Selects specialist lanes. It should broaden coverage when confidence is low and explain routing with citations to metadata or document text.

### Specialist Agents

These are reusable legal shared agents:

- `legal-contract-specialist`
- `legal-compliance-specialist`
- `legal-ip-specialist`
- `legal-privacy-specialist`
- `legal-employment-specialist`
- `legal-corporate-specialist`
- `legal-litigation-specialist`
- `legal-real-estate-specialist`

Each specialist returns structured findings, risks, citations, recommended actions, confidence, and human-review flags.

### Review And Output Agents

`legal-synthesis-agent`

Combines specialist outputs into cross-document findings, risk matrix, recommendations, conflicts, and questions for the attorney.

`legal-quality-reviewer`

Checks unsupported assertions, missing citations, conflicting specialist findings, low-confidence conclusions, and local-only policy compliance.

`legal-arbitrator`

Resolves disagreement between specialist output and reviewer objections. It records selected position, rationale, dissent notes, and whether HITL must decide.

`legal-hitl-coordinator`

Builds the human review payload, pauses the workflow, applies approve/reject/modify decisions, and creates rerun instructions when the attorney rejects or requests changes.

`legal-report-writer`

Produces final markdown and artifact instructions after approval.

`legal-output-validator`

Verifies final output against the workflow output contract before completion.

## Work Teams

Document onboarding should define work teams explicitly.

`source-intake-team`

- lead: `legal-source-resolver`
- worker: `legal-document-intake-agent`
- verifier: `legal-quality-reviewer`
- skills: `legal-document-source`, `legal-document-intake`

`metadata-team`

- lead: `legal-metadata-analyst`
- verifier: `legal-quality-reviewer`
- skills: `legal-metadata-extraction`

`routing-team`

- lead: `legal-clo-router`
- verifier: `legal-quality-reviewer`
- arbitrator: `legal-arbitrator`
- skills: `legal-clo-routing`

`specialist-panel-team`

- lead: `legal-document-onboarding-coordinator`
- participants: selected specialist agents
- verifier: `legal-quality-reviewer`
- arbitrator: `legal-arbitrator`
- skills: `legal-specialist-review`
- execution: parallel where the model/provider/tooling supports it, sequential on single-stream local Ollama
- Apple Orchestrator's current local Pi wrapper is synchronous, so local Ollama specialist lanes should run sequentially until the runtime has an async queue.

`synthesis-team`

- lead: `legal-synthesis-agent`
- verifier: `legal-quality-reviewer`
- arbitrator: `legal-arbitrator`
- skills: `legal-synthesis`

`human-review-team`

- lead: `legal-hitl-coordinator`
- skills: `legal-human-review`

`output-team`

- lead: `legal-report-writer`
- verifier: `legal-output-validator`
- skills: `legal-output-packet`

## Required Pi Extension Tools

The app needs a project extension that registers workflow tools:

- `workflow_call_agent`
- `workflow_run_team`
- `workflow_call_dynamic_agent`
- `workflow_promote_dynamic_agent`
- `workflow_emit_event`
- `workflow_append_run_entry`
- `workflow_write_plan`
- `workflow_resolve_client_matter`
- `workflow_list_source_options`
- `workflow_resolve_documents`
- `workflow_extract_text`
- `workflow_request_human_review`
- `workflow_wait_for_human_review`
- `workflow_write_artifact`
- `workflow_structured_output`

These tools are not optional glue. `workflow_call_agent` is how the workflow agent delegates work to named Apple Orchestrator agent specs under `.pi/agents`. The workflow tools are how Pi-driven agents talk to the Apple app and the local workflow database without bypassing permissions or the UI contract.

## No-Shortcut Rules

- Do not encode agent behavior only in JSON.
- Do not replace a known workflow agent with a generic JSON runner.
- Do not treat `.pi/agents` as native Pi resource discovery; it is loaded by the Apple Orchestrator extension.
- Do not make the Swift frontend resolve clients, matters, or external legal data.
- Do not treat HITL as a status string. It must be a Pi tool/UI request and durable workflow entry.
- Do not finalize legal workflow output without the HITL contract being satisfied.
- Do not hide work teams inside one monolithic prompt.
- Do not force workflow-specific phase behavior into shared agents unless it is truly reusable.
- Do not use cloud routes for `local-only` workflows.
- Do not discard raw Pi events; preserve them for diagnostics and normalize separately for the app.
