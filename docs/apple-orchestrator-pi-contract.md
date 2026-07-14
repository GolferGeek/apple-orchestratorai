# Apple Orchestrator Pi Contract

Apple Orchestrator AI runs on Pi, but the product concepts are not all Pi-native.

Pi gives us:

- Agent Skills in `.pi/skills/**/SKILL.md`
- extension tools in `.pi/extensions/**`
- prompt templates in `.pi/prompts/**`
- sessions, SDK/RPC events, model routing, and tool execution

Apple Orchestrator adds:

- workflow agents
- project-local agent specs
- work teams
- role delegation
- workflow events
- HITL records
- run entries
- output packets
- pause/resume state

Those Apple Orchestrator concepts are implemented by the runtime extension and the app. They should not be described as native Pi features.

## Directory Contract

```text
.pi/
  agents/
    *.md
  skills/
    <skill>/SKILL.md
  extensions/
    workflow-tools/index.ts
  prompts/
    *.md
```

## Native Pi Resources

`.pi/skills`, `.pi/extensions`, and `.pi/prompts` are Pi-discovered resources.

Skills are description-driven. The `description` field is part of the runtime contract because Pi only sees skill names and descriptions until the agent explicitly reads the full skill.

Extensions own product behavior that Pi does not provide directly. The workflow extension is responsible for registering app-specific tools, persisting events, managing human review records, spawning child Pi processes, and exposing enough structure for the Apple app to render workflow progress.

Prompt templates are launch surfaces. They may select a workflow agent and skills, but they must not become a generic JSON workflow runner.

## Apple Orchestrator Agent Specs

`.pi/agents/*.md` files are Apple Orchestrator agent specs. Pi does not auto-discover this folder.

The workflow extension loads these files through `workflow_call_agent`. Each file has frontmatter plus a system prompt body:

- `name`: stable kebab-case id
- `description`: what the agent does and when to call it
- `tools`: optional comma-separated tool allowlist
- `model`: optional default model

The extension appends the body as a system prompt to an isolated Pi child process and passes the task prompt to that child process.

This means project-local agents are real execution units in our product, but they are not native Pi objects. The extension is the bridge.

## Workflow Agent Rule

Each known product workflow should have exactly one workflow agent.

The workflow agent owns:

- workflow phases
- graphs and subgraphs
- work units
- work teams
- role delegation
- required skills
- model policy
- HITL checkpoints
- output contracts
- pause/resume rules

The workflow agent may call shared skills and shared project-local agents, but it remains responsible for the workflow shape. JSON may describe or catalog the workflow, but JSON must not execute the workflow.

## Work Teams

A work team is an Apple Orchestrator execution pattern, not a Pi primitive.

A work team is made of roles. Roles are performed by project-local agent specs, dynamic agent specs, or direct tool/skill work. The workflow agent or `workflow_run_team` tool is responsible for:

- emitting `team.started`
- emitting `role.started`
- invoking each role
- persisting each role output
- resolving arbitration or review
- emitting `role.completed`
- emitting `team.completed`

The first implementation can run roles sequentially for local Ollama. Parallel execution should be added only when the runtime can correlate events and control model capacity safely.

## Dynamic Agents

Dynamic agent specs are allowed only for exploratory or non-productized roles.

A dynamic agent may run once from a validated spec. If it succeeds and a human accepts it, the extension may promote it into `.pi/agents/*.md`. Promotion turns the dynamic role into a permanent Apple Orchestrator agent spec.

Dynamic agents must not own finalization, HITL, artifact writing, or app state unless an approved tool explicitly allows it.

## Event Contract

Pi events should be preserved for diagnostics. Apple Orchestrator workflow events should be normalized separately with product correlation fields:

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

The Apple app renders normalized workflow events, not raw Pi protocol events.

## No-Shortcut Rules

- Do not treat `.pi/agents` as native Pi discovery.
- Do not replace a known workflow agent with a generic JSON runner.
- Do not hide a work team inside one large prompt when role-level output matters.
- Do not let child agents perform app-owned side effects unless their tool allowlist explicitly permits it.
- Do not make the Swift frontend resolve legal client, matter, or document data. It asks the runtime.
- Do not finalize legal workflow output without HITL and output validation.
