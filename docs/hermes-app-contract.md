# Hermes App Contract

Hermes and the Apple app communicate through typed JSON.

Hermes owns workflow logic and content. The Apple app owns generic rendering.

The contract should include:

- display responses
- view models
- view blocks
- events
- actions
- outputs
- artifacts
- workflow catalog entries
- workflow explanations
- workflow refinement proposals

The contract should not force a single output path. Hermes skills may:

- return output metadata for the app to render
- update an existing output
- generate a local file
- generate an artifact bundle
- write a document into a matter workspace
- ask the app to open, preview, export, or save an output

Most workflows should still expose a final output contract to the app. Hermes can fulfill that contract with one artifact or with a multi-file output package.

Graphs, subgraphs, work units, and human checkpoints may also expose output contracts. This lets the app render review packages generically when a human is asked to approve, reject, or request changes.

Human checkpoints may be whole-package or segmented. For segmented review, Hermes should provide segment ids, labels, output references, allowed decisions, and any current recommendation. The app returns user decisions by segment id.

## Generic Blocks

The Apple app should render standard block types:

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
- `outline`
- `explanation`
- `diff_preview`
- `workflow_map`

## Workflow Explanation Responses

Hermes should be able to explain workflows and workflow parts without exposing raw JSON as the primary UI.

Example:

```json
{
  "schema_version": "0.1",
  "kind": "workflow.explanation",
  "workflow_id": "wf_document_onboarding",
  "target": {
    "type": "subgraph",
    "id": "extract_and_classify"
  },
  "title": "Extract and Classify Documents",
  "summary": "This subgraph reads selected matter documents, extracts text and metadata, and classifies the documents by type so later steps know how to use them.",
  "sections": [
    {
      "heading": "What it needs",
      "items": ["Selected files", "Document type hints when available"]
    },
    {
      "heading": "What it produces",
      "items": ["Document inventory", "Extracted text", "Classification table"]
    },
    {
      "heading": "Human review",
      "items": ["The user may correct document classifications before final summary generation."]
    }
  ],
  "actions": [
    { "id": "request_change", "label": "Request Change" },
    { "id": "show_related_outputs", "label": "Show Outputs" }
  ]
}
```

## Workflow Refinement Proposals

When a user asks to change a workflow, Hermes should propose a structured change instead of silently rewriting the file.

The proposal should include:

- plain-English explanation
- affected workflow/subgraph/work unit
- JSON patch or equivalent structured edit
- risk/impact summary
- approve/reject actions

The app can render this as a diff preview and apply it only after user approval.

## Live Updates

Hermes already exposes local SSE-style streams through its API server. The Apple app should use those streams as the transport and normalize them into its local observability database and generic UI blocks.

Preferred integration:

1. Start a workflow or long-running agent action with `POST /v1/runs`.
2. Store the returned `run_id`.
3. Subscribe to `GET /v1/runs/:run_id/events`.
4. Poll or reconcile with `GET /v1/runs/:run_id` when the app reconnects.
5. Resolve human approvals with `POST /v1/runs/:run_id/approval`.
6. Pause a resumable run with `POST /v1/runs/:run_id/pause`.
7. Resume a paused run with `POST /v1/runs/:run_id/resume`.
8. Stop a run with `POST /v1/runs/:run_id/stop`.

Run ids are the durable lifecycle handles. The app may have many active run records and many active event subscriptions, one per `run_id`. Hermes owns actual scheduling and concurrency. On local Ollama routes, Hermes may run workflows concurrently, serialize model-bound work, or queue work based on model capacity, available memory, workflow policy, and tool safety. The app should not assume parallel execution just because multiple runs are active.

Lifecycle statuses:

- `queued`
- `started`
- `running`
- `paused`
- `waiting_for_human`
- `completed`
- `failed`
- `cancelled`
- `stopped`

`paused` means Hermes intentionally preserved resumable run state. `waiting_for_human` means Hermes is blocked on a human checkpoint and should be resumed through the approval contract, not generic resume.

The first concrete request and response schemas are:

- `schemas/workflows/run-start.v0.schema.json`
- `schemas/workflows/run-status.v0.schema.json`
- `schemas/workflows/approval-response.v0.schema.json`
- `schemas/workflows/workflow-explanation.v0.schema.json`

Human approval responses are intentionally generic. The app sends `review_id`, an overall decision, optional note, and segment decisions. Hermes owns how that response resumes or revises the workflow.

Known Hermes run events include:

- `message.delta`
- `approval.request`
- `approval.responded`
- `run.paused`
- `run.resumed`
- `run.completed`
- `run.failed`
- `run.cancelled`

Hermes also exposes:

- Chat Completions streaming through `POST /v1/chat/completions` with `stream: true`.
- Responses API streaming through `POST /v1/responses` with `stream: true`.
- Session streaming through `POST /api/sessions/:session_id/chat/stream`.

The app should preserve the raw Hermes event envelope for audit/debugging, then write normalized rows for:

- run status
- current step text
- tool progress
- message deltas
- approval requests
- approval responses
- final output
- failure/cancellation

## Skill Event Detail

Skills should report progress and outputs to Hermes, and Hermes should emit one normalized workflow event envelope to the app. Skills should not write directly to the app database.

The shared event schema is:

```text
schemas/workflows/workflow-event.v0.schema.json
```

Skill-aware events may include:

- `graphId`
- `subgraphId`
- `workUnitId`
- `skillId`
- `status`
- `summary`
- `message`
- `progress`
- `metrics`
- `outputs`
- `raw`

The app renders known fields generically and preserves `raw` for audit/debugging. Workflow-specific interpretation remains inside Hermes skills.

## Native Hermes vs App Display Contract

Hermes' native API is the transport and lifecycle contract. The Apple display contract is a product-level layer on top of it.

Do not fork Hermes just to create a second event system. Instead, add skills or compatibility endpoints that emit the domain view models the app needs:

- workflow catalog entries
- workflow explanations
- workflow map blocks
- output package descriptors
- human review segment descriptors
- workflow refinement proposals

The app can render ordinary Hermes streaming text directly in the agent conversation surface, but workflow screens should prefer typed display envelopes and blocks.

## V0 Files Added

The first concrete contract files are now:

- `schemas/workflows/display-envelope.v0.schema.json`
- `schemas/workflows/workflow-run.v0.schema.json`
- `schemas/workflows/human-review.v0.schema.json`
- `schemas/workflows/workflow-event.v0.schema.json`
- `schemas/workflows/run-start.v0.schema.json`
- `schemas/workflows/run-status.v0.schema.json`
- `schemas/workflows/approval-response.v0.schema.json`
- `schemas/workflows/workflow-explanation.v0.schema.json`
- `test-fixtures/legal/document-onboarding/acme-renewal/run-completed.json`

The Mac app renders those records through generic SwiftUI blocks:

- workflow catalog cards
- stage timeline blocks
- human review segment blocks
- output blocks

This is still intentionally generic. Document onboarding does not get a bespoke result screen; it gets a workflow catalog entry and a run/output record that any workflow can use.

## Document Onboarding Runner

The current executable path is:

```bash
scripts/run-document-onboarding-workflow.sh
```

It calls Hermes through the local gateway once per workflow stage, writes stage results to `.runtime/apple-local-state/stage-results/`, appends JSONL events to `.runtime/apple-local-state/events/`, writes the final envelope to `.runtime/apple-local-state/display-envelopes/`, and writes the normalized run record to `.runtime/apple-local-state/runs/`.

That script is the bridge from the prompt-only fixture smoke test toward the real workflow runner. The next implementation step is to replace each compact stage prompt with the corresponding Hermes workflow skill implementation while preserving the same event and persistence contract.

## Native App Run Start

The Mac app now has the first native run-start path:

1. The user says "run document onboarding" or presses **Run Document Onboarding** in the workflow catalog.
2. `HermesRunClient` calls `POST /v1/runs`.
3. The returned Hermes `run_id` creates an in-memory `WorkflowRunRecord`.
4. The run record is mirrored to `.runtime/apple-local-state/runs/`.
5. `HermesEventClient` immediately subscribes to `GET /v1/runs/{run_id}/events`.
6. Incoming events update `AppState` and are mirrored to `.runtime/apple-local-state/events/{run_id}.jsonl`.

This keeps Hermes as the event source and SwiftUI as the reactive renderer. The local state files remain the recovery/audit mirror.

## Legal Source Picker Contract

The Apple app must not query client, matter, or document stores directly.

For document onboarding and similar workflows, the app renders a generic picker and asks Hermes for each list:

1. `clients`
2. `matters` for a selected client id
3. `documents` for a selected matter id

Hermes owns source resolution. The backing source may be Apple local state, a local fixture, SQL Server through MCP, Supabase through MCP, a document management MCP, or a firm-specific connector. The app only renders the returned picker options and sends selected ids back to Hermes when starting the workflow.

The picker response schema is:

```text
schemas/workflows/picker-options.v0.schema.json
```

The first skill contract is:

```text
skills/legal/shared/list-legal-source-options.skill.json
```

The Mac app surface is intentionally generic: it shows clients, matters, and documents, but it does not know how those were discovered.
