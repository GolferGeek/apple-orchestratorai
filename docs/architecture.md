# Apple Orchestrator AI Architecture

## Intent

Apple Orchestrator AI recreates the local OrchestratorAI experience as native Apple apps:

- Mac first
- iPhone controller
- iPad controller later

The goal is hierarchical workflow construction and execution:

```text
Workflow
  Graph
    Subgraph
      Work Unit
        Work Team or Agent
          Outputs
```

The important distinction is that the system is skills-driven rather than hard-coded. Workflow definitions live as skills. The local database exists underneath the skills as an observability, state, output, cache, and audit layer.

## Product Boundary

Apple Orchestrator AI Local is Mac-first. The Mac is the execution node:

- Hermes runs on the Mac.
- Ollama runs on the Mac.
- Workflow JSON files live on the Mac.
- Matter workspaces live on the Mac.
- The local observability database lives on the Mac.
- MCP tools/connectors are initiated from the Mac.

iPhone and iPad are controllers. They can start runs, view progress, approve human-in-the-loop tasks, answer Hermes questions, and view outputs, but they do not run the workflow engine or heavy model work.

Hermes should be bundled with the Mac app. Treat Hermes as an upgradeable local runtime made of files, folders, skills, workflow packs, schemas, and configuration. The app installer or updater can install or upgrade Hermes in place while preserving user workflow files, matter workspaces, run history, and connector configuration.

Initial platform sequence:

1. Mac app with bundled Hermes and local execution.
2. iPhone controller for run status, approvals, capture, and steering.
3. iPad controller using the same display contract, optimized for review and planning.

## Skills-First Model

The app should be able to create and run new workflow structures without adding new app code for each workflow type. A workflow is primarily a skill or collection of skills, not a database record that tries to encode all behavior.

The database should not be the brain of the system. It should be the ledger and local working memory.

## Workflow Structure Files

Workflow structure should be stored as local Apple files, not primarily as database rows. A workflow definition can be a JSON document that Hermes can read, write, diff, copy, archive, and promote between lifecycle states.

The JSON file describes the user's intended structure:

- workflow identity
- lifecycle status, such as `dev`, `test`, `prod`, or `archived`
- graph and subgraph structure
- work units
- required skills
- required MCP resources/connectors
- expected inputs
- expected outputs
- human-in-the-loop checkpoints
- display preferences or render hints

Hermes can discover available workflows by scanning the workflow definition folder. This keeps workflow authoring local, portable, inspectable, and compatible with Apple document storage.

Example:

```json
{
  "schema_version": "0.1",
  "workflow_id": "wf_matter_intake",
  "name": "Matter Intake",
  "status": "dev",
  "description": "Create an initial matter summary from selected files and matter data.",
  "required_skills": [
    "legal.extract_parties",
    "legal.extract_claims",
    "legal.timeline_builder",
    "legal.intake_summary"
  ],
  "resources": [
    { "resource_id": "matter_files", "type": "mcp", "connector": "local_folder", "required": true },
    { "resource_id": "matter_data", "type": "mcp", "connector": "sql_server", "required": false }
  ],
  "graph": {
    "nodes": [
      { "id": "collect_context", "type": "work_unit", "skill": "legal.collect_context" },
      { "id": "analyze_documents", "type": "work_unit", "skill": "legal.extract_claims" },
      { "id": "human_review", "type": "human_task", "title": "Review extracted facts" },
      { "id": "write_summary", "type": "work_unit", "skill": "legal.intake_summary" }
    ],
    "edges": [
      { "from": "collect_context", "to": "analyze_documents" },
      { "from": "analyze_documents", "to": "human_review" },
      { "from": "human_review", "to": "write_summary" }
    ]
  },
  "outputs": [
    { "id": "intake_summary", "format": "markdown", "render_as": "document" },
    { "id": "fact_table", "format": "json", "render_as": "table" }
  ]
}
```

The workflow file should contain lifecycle status, but not volatile live run state. For example, `dev`, `test`, `prod`, and `archived` belong in the workflow JSON. Active run status, step progress, errors, human tasks, and produced outputs belong in the local observability database and Hermes event stream.

## Domain Workflow Packs

The first workflow pack should be legal. It can be based on the previous OrchestratorAI Local legal work and converted into Hermes-readable workflow JSON files plus the skills needed to run them.

This model should generalize beyond legal:

- Lawyers and legal students can start with legal workflow packs.
- Accountants can generate their own workflow JSON files or install accountant-focused workflow packs.
- Other professions can add domain packs without requiring custom app screens.

The Apple app remains the same. Hermes reads the workflow JSON, invokes the necessary skills, and emits generic display responses. The domain-specific behavior lives in the workflow files and skills, not in hard-coded UI.

Potential pack structure:

```text
WorkflowPack
  manifest.json
  workflows/
    matter-intake.workflow.json
    discovery-review.workflow.json
    draft-motion.workflow.json
  skills/
    legal.extract-parties/
    legal.discovery-review/
    legal.motion-draft/
  examples/
    test-matter/
```

The pack manifest can identify domain, version, required skills, sample data, and compatibility with Hermes/App contract versions.

Example:

1. A user asks Hermes or the app to run a workflow skill.
2. The skill defines or discovers the graph, subgraphs, and work units needed.
3. The skill asks for any missing MCP tools, connectors, credentials, files, or data access.
4. A work unit declares what it needs:
   - input data
   - files
   - matter/client context
   - agent or team capability
   - output contract
5. Hermes routes the work through local models, Ollama, MCP tools, connectors, human-in-the-loop steps, or other skills.
6. The runtime writes structured state, status, outputs, artifacts, and audit events to the local database.

This keeps the product configurable without forcing every workflow definition into tables. Skills own workflow behavior. The database makes that behavior visible, resumable, inspectable, and auditable.

## Local Observability Database

The local database exists for the app UI and durable runtime state. It should answer questions like:

- What workflows are available?
- What runs are active?
- What is waiting for human input?
- What is currently processing?
- What failed?
- What files/data sources were used?
- What outputs were produced?
- What happened in this matter workspace?

This is similar to OrchestratorAI's operational view: running, completed, blocked, failed, and human-in-the-loop workflow activity.

## Hermes-to-App Display Contract

Because the Mac app sits on top of a Hermes installation, Hermes should expose an explicit display contract for the Apple app. The Mac app should not need to understand the internals of every skill, and it should not need a custom UI for each workflow.

Hermes owns workflow logic and content. The Apple app owns a small set of generic renderers.

Hermes can provide this in two forms:

- **Snapshot API:** The app asks for current state, such as active runs, completed runs, blocked runs, available skills, pending human tasks, and renderable views.
- **Event stream:** Hermes pushes updates as runs progress, such as step started, step completed, output produced, human input needed, connector needed, run failed, or view model updated.

Current Hermes Agent already provides a local API server on the gateway process. The Apple app should use this as the first transport:

- `GET /v1/capabilities` for feature discovery.
- `GET /v1/skills` and `GET /v1/toolsets` for deterministic capability listing.
- `POST /v1/runs` to start long-running work.
- `GET /v1/runs/:run_id/events` for Server-Sent Events.
- `GET /v1/runs/:run_id` for reconnect/poll status.
- `POST /v1/runs/:run_id/approval` for human-in-the-loop approvals.
- `POST /v1/runs/:run_id/stop` for cancellation.
- `/api/sessions` and `/api/sessions/:id/chat/stream` for the agent conversation surface.

That native Hermes API is the lifecycle transport. The Apple-specific display contract remains a schema layer above it, because Hermes run events do not by themselves describe every workflow catalog view, review package, output package, or workflow refinement diff the product needs.

The display contract should be generic and schema-driven. Hermes can send standard view blocks:

- `status`
- `list`
- `table`
- `timeline`
- `detail`
- `form`
- `decision`
- `artifact`
- `log`
- `metric`
- `chart`
- `action_bar`

The Apple app renders these blocks consistently. A legal intake workflow, discovery review workflow, research workflow, and drafting workflow should all use the same UI primitives.

Hermes responses to the Apple app should always use a typed JSON envelope. In Swift terms, the app should decode the envelope into protocol-backed models such as `HermesDisplayResponse`, `HermesViewBlock`, and `HermesAction`.

Conceptual Swift interfaces:

```swift
protocol HermesDisplayResponse {
    var responseId: String { get }
    var kind: HermesResponseKind { get }
    var views: [HermesView] { get }
    var events: [HermesEvent] { get }
    var actions: [HermesAction] { get }
}

protocol HermesViewBlock {
    var id: String { get }
    var type: HermesBlockType { get }
    var title: String? { get }
    var summary: String? { get }
}
```

Every Hermes-to-app response should be valid against the shared schema. Unknown block types can be ignored or shown as unsupported blocks, but they should not break the app.

Initial view model shape:

```json
{
  "schema_version": "0.1",
  "response_id": "resp_123",
  "kind": "display.update",
  "views": [
    {
      "view_id": "view_run_456",
      "run_id": "run_456",
      "skill_id": "legal.matter_intake",
      "matter_workspace_id": "matter_789",
      "title": "Matter Intake",
      "subtitle": "Smith v. Acme",
      "status": "running",
      "progress": 0.35,
      "blocks": [
        {
          "id": "block_status_1",
          "type": "status",
          "title": "Reading pleadings",
          "summary": "Hermes is extracting parties, claims, dates, and requested relief."
        },
        {
          "id": "block_timeline_1",
          "type": "timeline",
          "items": [
            { "label": "Workspace created", "status": "completed" },
            { "label": "Files indexed", "status": "completed" },
            { "label": "Pleadings analysis", "status": "running" }
          ]
        },
        {
          "id": "block_actions_1",
          "type": "action_bar",
          "actions": [
            { "id": "pause", "label": "Pause", "style": "secondary" },
            { "id": "open_outputs", "label": "Open Outputs", "style": "primary" }
          ]
        }
      ]
    }
  ],
  "events": [],
  "actions": []
}
```

Initial event shape:

```json
{
  "event_id": "evt_123",
  "run_id": "run_456",
  "skill_id": "legal.matter_intake",
  "type": "view.updated",
  "timestamp": "2026-07-07T12:00:00Z",
  "view_id": "view_run_456"
}
```

Core event types:

- `run.created`
- `run.started`
- `run.progress`
- `run.completed`
- `run.failed`
- `run.blocked`
- `step.started`
- `step.progress`
- `step.completed`
- `step.failed`
- `human_task.created`
- `human_task.resolved`
- `connector.required`
- `resource.bound`
- `output.produced`
- `artifact.created`
- `view.updated`
- `action.requested`
- `action.completed`

The Mac app consumes these events and view models, then stores the normalized subset in the local observability database. That gives the UI durable lists, filters, status indicators, timelines, summaries, forms, actions, notifications, and output views without making the UI responsible for orchestration logic.

The same contract can drive iPad and iPhone views. The phone does not need to run the work; it can render the same generic blocks, approve human tasks, answer questions, and send action messages back to Hermes.

## Observables and Live Updates

For the initial Apple app, the UI needs observables that update when the local runtime/database changes. The app should be able to watch:

- what is being worked on
- which runs are active
- which runs are blocked
- which items need human input
- which outputs are ready to view
- how a run is progressing
- what errors or connector requests need attention

This is the Apple equivalent of the web-world pattern where one part of the app fires messages and another part receives them. The implementation can use local database observation inside the Apple app and a Hermes event stream across the Hermes/app boundary.

Recommended layers:

- **Hermes event stream:** Hermes emits `HermesDisplayResponse`, `HermesEvent`, and view updates as work changes.
- **Local observability database:** The app persists normalized run state, events, human tasks, and output metadata.
- **Apple observable model:** SwiftUI views subscribe to local state using `Observable`, `@Observable`, `ObservableObject`, Combine, or SwiftData/Core Data observation depending on the chosen persistence layer.
- **Action channel:** The app sends user actions back to Hermes, such as approve, reject, answer question, pause run, resume run, open connector, or view output.

SSE is viable for Apple clients. A Mac app can consume Server-Sent Events over HTTP using `URLSession` streaming APIs, or the runtime can use WebSockets if bidirectional communication is more important. For this product, the clean split is:

- **SSE or local event stream from Hermes to Apple app** for status/view updates.
- **HTTP/JSON action calls from Apple app to Hermes** for user decisions and commands.

If bidirectional low-latency messaging becomes central, use WebSockets. For the first version, SSE plus HTTP actions is simpler and matches the web architecture.

Core observable topics:

- `runs`
- `run_steps`
- `human_tasks`
- `outputs`
- `artifacts`
- `connectors`
- `resources`
- `errors`
- `notifications`

Output display should also be schema-driven. Outputs may be plain text, Markdown, JSON, tables, PDFs, document references, file bundles, citations, charts, or decision briefs. Hermes should return output metadata with a render hint rather than requiring a custom UI per output type.

Example output metadata:

```json
{
  "output_id": "out_123",
  "run_id": "run_456",
  "title": "Matter Intake Summary",
  "format": "markdown",
  "render_as": "document",
  "summary": "Initial parties, claims, dates, and missing information.",
  "artifact_refs": ["artifact_pleadings_summary"],
  "created_at": "2026-07-07T12:00:00Z"
}
```

## Core Tables or Entities

Initial conceptual entities:

- `skills`
- `skill_versions`
- `skill_capabilities`
- `matter_workspaces`
- `workspace_files`
- `workspace_data_refs`
- `runs`
- `run_steps`
- `run_events`
- `human_tasks`
- `outputs`
- `artifacts`
- `mcp_resources`
- `resource_bindings`
- `connectors`
- `access_policies`
- `audit_events`

## Service Layer

The service layer exists behind Hermes, skills, and the local observability database:

- **HermesRuntimeService:** Conversational runtime, skill routing, and execution coordination.
- **SkillService:** Discovers, installs, versions, validates, and invokes workflow skills.
- **RunService:** Owns active/completed/failed/blocked run state.
- **RunEventService:** Records detailed execution events for UI, audit, and debugging.
- **HumanTaskService:** Tracks approvals, questions, reviews, and other human-in-the-loop pauses.
- **WorkspaceService:** Manages bounded local matter workspaces.
- **AgentService:** Executes or delegates agent/model work.
- **McpResourceService:** Tracks resource definitions and scoped access for MCP-backed tools.
- **ResourceBindingService:** Records which workflow runs and matter workspaces used which resources.
- **ConnectorService:** Implements adapters for SharePoint, iManage, NetDocuments, Box, Google Drive, local folders, SQL databases, APIs, and similar sources.
- **PolicyService:** Controls access, scope, retention, legal holds, and audit behavior.

## MCP Resources and Connectors

MCP resources and connectors are configurable access paths to external resources. They solve the legal-professional problem: a workflow skill often needs both documents and structured matter/client data, but every organization stores those differently.

The key idea is that a skill, run, matter workspace, or work unit can declare the MCP resources it needs. Hermes can then ask the user to attach the right tool or connector.

### File Resources

A file resource describes where files live and how they are accessed through an MCP-backed tool or connector.

Examples:

- local folder
- iCloud Drive
- SharePoint
- OneDrive
- Google Drive
- Box
- Dropbox
- iManage
- NetDocuments
- Clio documents
- case-specific document repository

The file resource should define:

- connector type
- authentication method
- base path or workspace
- matter/client binding rules
- indexing rules
- file selection rules
- permission scope
- retention/audit requirements

### Data Resources

A data resource describes where structured business data lives and how it is accessed through an MCP-backed tool or connector.

Examples:

- client database
- matter database
- practice management system
- billing/timekeeping system
- CRM
- document metadata database
- SQL database
- REST/GraphQL API
- CSV import
- local SQLite/SwiftData store

The data resource should define:

- connector type
- schema mapping
- entity mapping, such as client, matter, party, document, deadline, invoice, task
- authentication method
- query permissions
- caching policy
- sync policy
- audit policy

## Resource Bindings

Resource bindings connect skills, runs, matter workspaces, and work units to MCP resources.

Examples:

- A workflow skill requests access to the firm's matter database.
- A matter workspace binds to a SharePoint matter folder.
- A run binds to a discovery document set.
- A work unit binds to a specific client record and a filtered file collection.

This means every hierarchy level can have its own path to data and files when needed, without making that a custom code path or a custom UI.

## Legal Use Case

The first strong market framing is young legal professionals and legal students.

They need to:

- understand a matter
- gather files
- retrieve client and matter data
- organize work into repeatable workflow skills
- delegate research, drafting, review, and analysis to agents
- preserve outputs and reasoning
- maintain auditability

The architecture should assume a workflow skill may need to attach to a legal system somewhere else. That system may expose documents separately from matter/client data. Hermes can ask for the needed MCP connector, such as SQL Server or a document system, and the local app records the resulting resource binding and run activity.

## Open Questions

- Which local database should back the first Apple build: SwiftData, SQLite, Core Data, or embedded SurrealDB-like service?
- Should graph execution run entirely on-device first, or through a local service process on Mac?
- What is the minimum connector set for the first legal prototype?
- Should file indexing be optional per resource, per matter, or per workflow?
- How should sync work across Mac, iPad, and iPhone?
- Which parts need Apple-native implementation versus a shared local service?
