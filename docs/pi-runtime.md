# Pi Runtime

Pi is an optional lightweight agent harness/workbench beside Hermes.

Hermes remains the product runtime for workflow execution, skills, run state, approvals, and event transport. Pi is added as a developer/admin workbench for editing and testing internals without turning normal workflow operation into a terminal experience.

## Intended Role

Pi should be used for:

- skill authoring and repair
- workflow JSON editing and validation
- prompt/template experiments
- local model behavior tests
- app/Hermes integration debugging
- course-style "build the system with the agent" work

Pi should not be the first execution runtime for legal workflows. If the product needs durable run state, human approval, MCP resource governance, or workflow observability, route that through Hermes and the Apple app contract.

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

Pi can propose changes to app internals, workflow files, Hermes skills, or Ollama/Hermes runtime configuration. The Apple app should approve, apply, test, and rollback those changes.

## Relationship to Hermes

Use Hermes for:

- workflow execution
- workflow observability
- human approval checkpoints
- long-running/ambient work
- MCP-governed resource access
- runtime event streams

Use Pi for:

- local agent workbench
- authoring/debugging workflows and skills
- experimenting with minimal harness behavior
- repairing generated source/config files

If Hermes later exposes or adopts Pi-compatible extension surfaces, the app can collapse some of this boundary. Until then, keep Pi optional and behind admin mode.
