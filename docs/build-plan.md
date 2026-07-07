# Build Plan

## Phase 1 — Real Hermes Bootstrap

- Install Hermes under `.runtime/hermes-agent`.
- Keep Hermes state under `.runtime/hermes-home`.
- Keep the Hermes virtual environment under `.runtime/venvs/hermes-dev`.
- Enable the Hermes local API server on `127.0.0.1:8642`.
- Verify `GET /health`, `GET /v1/capabilities`, and `GET /v1/models`.
- Verify `POST /v1/runs` accepts work and returns a `run_id`.
- Configure a local/provider model for the isolated Hermes home.
- Start one trivial run through `POST /v1/runs` and verify it reaches `run.completed`.

## Phase 1A — Pi Developer/Admin Harness

- Install Pi under `.runtime/pi`.
- Keep Pi app/workbench state under `.runtime/pi-home`.
- Verify the Pi CLI starts.
- Verify Pi RPC mode starts and responds to `get_state`.
- Add an app-facing Pi adapter that can spawn RPC mode, send commands, and stream JSONL events.
- Add a small admin frontend for Pi health, raw events, prompt testing, model state, abort, and new-session controls.

## Phase 2 — Contract Prototype

- Define workflow JSON schema.
- Define Apple display/action/event JSON schemas.
- Define Hermes profile routing and profile manifest schemas.
- Add a thin Hermes runtime adapter that wraps health, capabilities, runs, run events, approvals, stop, and session chat.
- Normalize Hermes run events into local app events.
- Convert only document onboarding to first-pass workflow JSON.

## Phase 3 — Local Observability

- Add local observability database.
- Persist runs, events, human tasks, outputs, and artifacts.
- Add SSE/event stream consumption.
- Add HTTP action calls back to Hermes.
- Render a generic run dashboard.

## Phase 4 — Legal Pack

- Refine document onboarding from prior OrchestratorAI Local work.
- Add local test matter.
- Add local file resource.
- Produce Markdown and table outputs.
- Add human-in-the-loop checkpoint.

## Phase 5 — Mac App Shell

- Start/stop/discover Hermes locally.
- Start/discover Pi locally for admin/developer workbench use.
- Select or route to the correct Hermes profile.
- List available workflows.
- Run one workflow through Hermes.
- Render generic blocks.
- Provide an agent conversation surface.
- Provide an advanced Pi workbench surface that is separate from normal workflow execution.

## Phase 6 — iPhone Controller

- View active runs.
- View outputs.
- Approve/reject human tasks.
- Send steering messages.

## Phase 7 — Catalog Conversion

- Convert the remaining 16 legal workflows after document onboarding proves the JSON shape.
- Preserve source references for every converted workflow.
- Keep each conversion conservative until tested.
