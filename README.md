# Apple Orchestrator AI

Apple Orchestrator AI is the local Apple-platform version of OrchestratorAI: a Mac-first app for building and running hierarchical AI workflows through Hermes, local workflow JSON files, local skills, local observability, and Ollama models.

The core product idea is local skills-driven orchestration. Workflow structure lives in JSON files. Workflow behavior lives in Hermes skills. External systems are accessed through MCP-backed tools and connectors. The local database records run state, outputs, human-in-the-loop tasks, events, and audit history.

## Product Shape

- **Mac app:** Primary authoring, operations, execution, Hermes runtime, and Ollama model host.
- **iPhone app:** Controller for capture, approvals, notifications, quick status, and steering.
- **iPad app:** Controller later for review, planning, and monitoring.
- **Local-only by default:** Hermes, skills, workflow files, matter workspaces, run state, and model execution stay on the Mac.
- **Connector-ready:** Hermes skills can use MCP tools to connect to external document systems, matter systems, client databases, and corporate data sources when the user configures access.

## Core Concepts

- **Workflow:** Top-level business process or legal process.
- **Graph:** Executable structure inside a workflow.
- **Subgraph:** Reusable or delegated portion of a graph.
- **Work unit:** Concrete unit of work in a graph.
- **Work team:** A single agent or group of agents/services responsible for a work unit.
- **Output:** Produced artifact, decision, structured result, file, note, or handoff.
- **MCP resource:** External file, database, API, or system access exposed to Hermes through a tool/connector.
- **Resource binding:** The scoped connection between a workflow run or matter workspace and an MCP resource.

## Key Architectural Intention

This should not be a custom-UI-per-workflow system. Hermes should drive workflows through skills and workflow JSON. The Apple app should render generic Hermes display responses and observe local run state.

When a skill needs external access, Hermes asks for or uses an MCP-backed resource:

- Workflow JSON defines the structure.
- Hermes skills provide behavior.
- MCP tools/connectors retrieve files, query databases, and call external systems.
- The local observability database records what is running, blocked, completed, waiting for human input, and produced as output.
- The Apple app renders generic status, timeline, table, form, artifact, and action blocks from Hermes.

See [docs/architecture.md](docs/architecture.md) for the initial model.

## Development Bootstrap

This repo owns the local Hermes, Pi, and Ollama bootstrap process, but runtime files stay out of git.

```bash
scripts/bootstrap-hermes.sh
source .runtime/hermes-env.sh
scripts/start-hermes-api.sh
```

In another terminal:

```bash
scripts/probe-hermes-api.sh
```

For the optional Pi developer/admin workbench:

```bash
scripts/bootstrap-pi.sh
source .runtime/pi-env.sh
scripts/probe-pi.sh
```

For local MLX model setup:

```bash
scripts/check-ollama-mlx.sh
scripts/upgrade-ollama-macos.sh
scripts/start-ollama-mlx.sh
scripts/pull-mlx-models.sh core
```

Development layout:

```text
.runtime/
  hermes-agent/
  hermes-home/
  pi/
  pi-home/
  ollama/
  venvs/hermes-dev/
```
