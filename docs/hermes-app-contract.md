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
6. Stop a run with `POST /v1/runs/:run_id/stop`.

Known Hermes run events include:

- `message.delta`
- `approval.request`
- `approval.responded`
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
