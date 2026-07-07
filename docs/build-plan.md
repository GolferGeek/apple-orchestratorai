# Build Plan

## Phase 1 — Contract Prototype

- Define workflow JSON schema.
- Define Hermes display/action/event JSON schemas.
- Build a Hermes mock server.
- Build a Mac app shell that reads mock runs and events.
- Render generic blocks.
- Convert only document onboarding to first-pass workflow JSON.

## Phase 2 — Local Runtime

- Add local observability database.
- Persist runs, events, human tasks, outputs, and artifacts.
- Add SSE/event stream consumption.
- Add HTTP action calls back to Hermes.

## Phase 3 — Real Hermes

- Bundle Hermes with the Mac app.
- Start/stop/discover Hermes locally.
- Discover workflow JSON files.
- Run one workflow through Hermes.

## Phase 4 — Legal Pack

- Refine document onboarding from prior OrchestratorAI Local work.
- Add local test matter.
- Add local file resource.
- Produce Markdown and table outputs.
- Add human-in-the-loop checkpoint.

## Phase 6 — Catalog Conversion

- Convert the remaining 16 legal workflows after document onboarding proves the JSON shape.
- Preserve source references for every converted workflow.
- Keep each conversion conservative until tested.

## Phase 5 — iPhone Controller

- View active runs.
- View outputs.
- Approve/reject human tasks.
- Send steering messages.
