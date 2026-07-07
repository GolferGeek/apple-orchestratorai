# Hermes Bundle

Hermes should be bundled with the Mac app as an upgradeable local runtime.

## Bundle Contents

Hermes is treated as a local folder structure containing:

- runtime files
- skills
- workflow pack loader
- schemas
- default configuration
- mock/demo data
- contract definitions
- scripts or binaries needed to run Hermes locally

## Upgrade Rule

The app may upgrade Hermes, but must preserve user-owned state:

- workflow JSON files
- installed workflow packs
- matter workspaces
- local observability database
- connector/resource configuration
- paired device records
- outputs/artifacts

## Install Shape

Potential local paths:

```text
~/Library/Application Support/AppleOrchestratorAI/
  Hermes/
  Workflows/
  WorkflowPacks/
  MatterWorkspaces/
  RuntimeState/
  Artifacts/
  Logs/
```

## App Responsibilities

The Mac app should:

- check Hermes installation
- install bundled Hermes if missing
- upgrade Hermes when app version requires it
- start/stop Hermes
- check Hermes health
- discover Hermes local URL/port
- show Hermes version
- surface Hermes errors

## Hermes Responsibilities

Hermes should:

- discover workflow JSON files
- discover installed skills
- validate workflow JSON
- run workflows
- expose snapshot endpoints
- expose event stream
- accept action calls
- write or emit run state for the local database/UI

## Local Runtime API

The app should communicate with Hermes through the Hermes API server exposed by `hermes gateway`.

Current Hermes Agent exposes an OpenAI-compatible API server when enabled:

```bash
hermes config set API_SERVER_ENABLED true
hermes config set API_SERVER_KEY <local-secret>
hermes gateway
```

Default bind:

```text
http://127.0.0.1:8642
```

The app should still discover the actual host/port from Hermes config and health checks rather than hard-coding it.

Confirmed endpoints relevant to the Apple app:

```text
GET /health
GET /health/detailed
GET /v1/models
GET /v1/capabilities
GET /v1/skills
GET /v1/toolsets
GET /api/sessions
GET /api/sessions/:session_id
GET /api/sessions/:session_id/messages
POST /api/sessions
POST /api/sessions/:session_id/chat
POST /api/sessions/:session_id/chat/stream
POST /v1/chat/completions
POST /v1/responses
GET /v1/responses/:response_id
DELETE /v1/responses/:response_id
POST /v1/runs
GET /v1/runs/:run_id
GET /v1/runs/:run_id/events
POST /v1/runs/:run_id/approval
POST /v1/runs/:run_id/stop
```

The API server requires bearer-token auth with `API_SERVER_KEY`, including on localhost. Browser CORS is disabled unless explicitly configured, which is appropriate for a native Mac app talking over loopback.

## App Integration Rule

Use Hermes' native API server first. Add an Apple-specific compatibility layer only for product concepts Hermes does not natively expose, such as workflow catalog display envelopes, workflow explanation blocks, and domain-specific output package metadata.

Preferred transport by use case:

- **Run execution and observability:** `POST /v1/runs`, `GET /v1/runs/:id`, and `GET /v1/runs/:id/events`.
- **Human approval:** `POST /v1/runs/:id/approval`.
- **Stop/cancel:** `POST /v1/runs/:id/stop`.
- **Agent conversation surface:** `/api/sessions/:id/chat/stream` or `/v1/responses` with streaming.
- **Capability discovery:** `GET /v1/capabilities`, `GET /v1/skills`, and `GET /v1/toolsets`.
- **Session history:** `/api/sessions` and `/api/sessions/:id/messages`.
