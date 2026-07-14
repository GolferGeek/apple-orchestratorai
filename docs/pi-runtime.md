# Pi Runtime

Pi is the preferred workflow execution harness for Apple Orchestrator AI.

Hermes remains in the repository as temporary scaffolding and a useful reference while Pi catches up. New workflow execution work should target Pi first. Once Pi covers workflow launch, progress events, human review, outputs, and run recovery, Hermes can be removed from this app and used separately for Apple Assistant-style work.

## Intended Role

Pi should be used for:

- workflow execution
- workflow observability
- work-team and agent orchestration through Apple Orchestrator extensions
- skill authoring and invocation
- MCP/tool-driven task execution
- human review checkpoints through app-normalized events
- skill authoring and repair
- workflow JSON editing and validation
- prompt/template experiments
- local model behavior tests
- course-style "build the system with the agent" work

The Apple app should not expose Pi as a terminal. Pi is the underlying runtime. The app renders workflow state, asks for human decisions, and sends typed launch/action payloads.

## Install Shape

During development, Pi is installed under ignored local runtime state:

```text
.runtime/
  pi/
  pi-home/
    agent/
    sessions/
  pi-env.sh
```

Bootstrap:

```bash
scripts/bootstrap-pi.sh
source .runtime/pi-env.sh
scripts/probe-pi.sh
```

Pi currently requires Node `22.19.0` or newer. The bootstrap script checks this before install/build.

The bootstrap env sets:

- `PI_CODING_AGENT_DIR=.runtime/pi-home/agent`
- `PI_CODING_AGENT_SESSION_DIR=.runtime/pi-home/sessions`
- `PI_TELEMETRY=0`

That keeps the app-owned Pi runtime separate from the user's normal `~/.pi` install and settings.

Bootstrap also seeds `.runtime/pi-home/agent/models.json` with an `ollama` provider pointing at the project-local Ollama runtime:

```text
http://127.0.0.1:11435/v1
```

It does not overwrite that file after you customize it.

## App Integration Surfaces

Pi exposes several useful integration surfaces:

- **CLI interactive mode:** useful for developers, not normal users.
- **Print/JSON mode:** useful for simple one-shot prompts and scripted checks.
- **RPC mode:** preferred first app integration because Swift can run a child process and exchange LF-delimited JSONL over stdin/stdout.
- **SDK mode:** preferred later for a Node/TypeScript sidecar or deeper embedded integration.

The first Apple app integration should target RPC mode:

```bash
pi --mode rpc --no-session
```

The RPC protocol supports commands such as:

- `prompt`
- `steer`
- `follow_up`
- `abort`
- `new_session`
- `get_state`
- `get_messages`
- `set_model`

The app must parse strict LF-delimited JSONL. It should preserve raw events for diagnostics and normalize only the subset it renders.

## Event Wrapper

Pi emits JSONL protocol events. The app should not render Pi events directly. A thin runtime adapter wraps them into the shared workflow event contract:

```text
Pi JSONL event -> PiRuntimeEvent -> workflow-event.v0 -> SwiftUI
```

The wrapper must add our missing product context:

- `runId`
- `workflowId`
- `stageId`
- `workUnitId`
- `skillId`
- `teamId`
- `roleId`
- `sessionId`
- `commandId`, when known

Pi RPC streaming events are not always tagged with the originating command id. For concurrent workflow execution, the safe approach is one Pi RPC worker per active run, work unit, or team role, or an app-owned wrapper that injects correlation metadata before events enter the app database.

The first normalized event mapping is:

| Pi event | Workflow event |
| --- | --- |
| `agent_start` | `work_unit.started` or `workflow.started` |
| `agent_end` | `work_unit.completed` or `workflow.completed` |
| `turn_start` | `runtime.turn.started` |
| `turn_end` | `runtime.turn.completed` |
| `message_start` | `runtime.message.started` |
| `message_update` | `runtime.message.updated` |
| `message_end` | `runtime.message.completed` |
| `tool_execution_start` | `tool.started` |
| `tool_execution_update` | `tool.updated` |
| `tool_execution_end` | `tool.completed` |
| `queue_update` | `runtime.queue.updated` |
| `compaction_start` | `runtime.compaction.started` |
| `compaction_end` | `runtime.compaction.completed` |
| `auto_retry_start` | `runtime.retry.started` |
| `auto_retry_end` | `runtime.retry.completed` |
| `extension_error` | `runtime.error` |
| `extension_ui_request` | `human_review.requested` or `runtime.ui.requested` |

Human-facing workflow screens should mostly render the workflow/stage/work-unit/human-review/output events. The raw Pi runtime events remain available in the advanced runtime view and in audit files.

The wrapper schema lives at:

```text
schemas/runtime/pi-runtime-event.v0.schema.json
```

The normalized workflow event schema remains:

```text
schemas/workflows/workflow-event.v0.schema.json
```

## Admin Frontend

The Mac app should include a small admin/workbench frontend for Pi, initially hidden behind an advanced or developer mode.

The first version can be generic:

- Pi health/version
- selected integration surface: CLI, RPC, SDK later
- current model/provider state
- prompt box
- streamed event log
- session list or session id
- raw JSONL inspector
- buttons for abort, new session, get state

This should not look like the main user workflow UI. It is a local admin console for building and repairing the system.

## Trust Boundary

Pi does not include a built-in permission system for restricting filesystem, process, network, or credential access. It runs with the permissions of the process that launched it.

Therefore:

- normal users should not reach Pi directly
- the app must decide when Pi is allowed to run
- Pi should run with project-specific cwd and explicit resource flags
- destructive updates should go through the app's runtime manager
- credentials should stay in app-governed storage or explicitly scoped Pi config

Pi can propose changes to app internals, workflow files, skills, or Ollama/runtime configuration. The Apple app should approve, apply, test, and rollback those changes.

## Relationship to Hermes

Keep Hermes temporarily for:

- reference contracts already built in this repo
- comparison while Pi reaches workflow parity
- possible reuse in the separate Apple Assistant app

Use Pi for:

- Apple Orchestrator AI workflow execution
- agent/team coordination
- skill execution
- event-stream normalization
- local agent workbench and admin tooling
- authoring/debugging workflows and skills

Once Pi can run document onboarding end to end through the shared workflow-event contract, remove Hermes from the core product path.

## Project Resource Contract

Workflow execution should use Pi's project-level resource discovery for native resources and one explicit Apple Orchestrator convention for agent specs:

```text
.pi/
  agents/
    legal-document-onboarding-coordinator.md
    legal-source-resolver.md
    legal-document-intake-agent.md
    legal-metadata-analyst.md
    legal-clo-router.md
    legal-*-specialist.md
    legal-synthesis-agent.md
    legal-quality-reviewer.md
    legal-arbitrator.md
    legal-hitl-coordinator.md
    legal-report-writer.md
    legal-output-validator.md
  skills/
    legal-document-source/SKILL.md
    legal-document-intake/SKILL.md
    legal-metadata-extraction/SKILL.md
    legal-clo-routing/SKILL.md
    legal-specialist-review/SKILL.md
    legal-synthesis/SKILL.md
    legal-human-review/SKILL.md
    legal-output-packet/SKILL.md
  prompts/
    document-onboarding.md
```

Pi natively discovers `.pi/skills`, `.pi/extensions`, and `.pi/prompts`.

Pi does not natively discover `.pi/agents`. That folder is an Apple Orchestrator convention consumed by `.pi/extensions/workflow-tools/index.ts`. The extension loads agent specs, appends their prompt bodies to isolated Pi child processes, applies their tool allowlists, and selects their frontmatter model.

The app's workflow JSON remains the catalog and output contract. The executable layer is the workflow agent spec, Pi skills, extension tools, and child Pi sessions.

The full contract is documented in:

```text
docs/apple-orchestrator-pi-contract.md
```
