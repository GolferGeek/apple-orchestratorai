# Generic Apple UI

The Apple app should not have custom screens per workflow.

It should provide generic views:

- workflows
- runs
- human tasks
- outputs
- matter workspaces
- resources/connectors
- Agent conversation
- Runtime diagnostics
- settings/models
- Admin/developer workbench

And generic renderers:

- status
- timeline
- table
- form
- detail
- artifact
- action bar

The UI renders Hermes display JSON and local observability state.

## Workflow Catalog and Explanation

The app should let the local agent list all available workflows and explain them in user terms. The UI should not show a workflow as a raw JSON file by default, and it should not feel like a Hermes terminal.

The workflow catalog should show:

- workflow name
- lifecycle status: dev, test, prod, archived
- short purpose
- when to use it
- required inputs
- expected outputs
- human review points
- required MCP resources/connectors
- estimated complexity or duration when known

Users should be able to drill into:

- graph
- subgraph
- work unit
- human checkpoint
- output package
- required resource

Each drill-in view should answer:

- what this part does
- why it exists
- what it needs
- what it produces
- where a human may approve or modify
- what can be changed safely

Hermes should generate these explanations from the workflow JSON, skills, and source metadata. The Apple app renders the explanations as structured cards, outlines, timelines, and detail panes.

This matters because users do not think with a complete global graph in their heads. They need to explore the workflow piece by piece, understand what each part is for, and refine it from that understanding.

## Workflow Refinement UI

The app should support refinement through conversation and structured actions:

- "Tell me more about this subgraph"
- "Why is this human checkpoint here?"
- "Move approval earlier"
- "Add a review step before final output"
- "Split this output into two files"
- "Make this workflow use a local folder instead of SQL Server"
- "Promote this workflow from dev to test"

Hermes should propose changes as a diff or structured patch to the workflow JSON. The app should render the proposed change in understandable language, then allow the user to approve or reject it.

The user should not need to edit JSON directly for normal workflow refinement.

## Interface Modes

The Mac app can offer two user-facing modes:

- **Apple Interface:** Native workflow/run/output UI using generic renderers.
- **Agent Conversation:** A conversational agent/workbench surface inside the Mac app.

The Agent Conversation is primarily powered by Hermes, but the user does not need to know they are talking to Hermes. They are talking to the app's local agent.

It should not look like a terminal by default. The normal experience should feel like a structured assistant/workbench:

- conversational input
- run-aware responses
- cards for suggested actions
- timeline/status blocks
- workflow JSON previews
- diff previews for proposed changes
- connector/resource prompts
- output previews
- diagnostics in readable panels

Raw logs or terminal-like output should be available only as an advanced/debug view.

This is useful for:

- talking to the local agent
- asking why a run is blocked
- asking what connector/resource is needed
- improving a workflow JSON file
- inspecting Hermes health
- viewing raw-ish events or logs
- debugging local runtime issues
- checking model/tool availability

The user should not need to leave the Mac app for normal runtime interaction. Hermes should remain an implementation detail unless the user opens advanced diagnostics.

## Pi Admin Workbench

The app can also include a small Pi-powered admin/developer workbench.

This is not the normal workflow UI. It is for building, testing, and repairing the system:

- workflow JSON edits
- skill/prompt experiments
- local model behavior tests
- Pi RPC diagnostics
- raw JSONL event inspection
- generated patch review
- controlled runtime-management requests

The first integration should use Pi RPC mode through a child process. Later, if useful, the app can move to a Node/TypeScript sidecar that embeds the Pi SDK.

The workbench should expose clear status:

- Pi installed/build status
- Pi version
- selected transport: CLI, RPC, SDK later
- model/provider state
- current session id
- raw event stream
- controls for prompt, abort, get state, and new session

Pi must stay behind the app trust boundary. The app approves file edits, runtime updates, model pulls, and other privileged operations.

## Hermes Runtime Discovery

The app needs to understand how to find Hermes locally.

Open investigation:

- What local port or URL does Hermes expose?
- Does Hermes provide `/health`?
- Does Hermes provide a workflow/run/event API?
- Does Hermes expose logs or diagnostic events?
- Can Hermes stream events over SSE or WebSocket?
- Can the app start Hermes if it is not running?
- Can the app distinguish bundled Hermes from a separately installed Hermes?
