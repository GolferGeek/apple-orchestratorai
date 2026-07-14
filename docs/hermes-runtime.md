# Hermes Runtime

Hermes is installed during development under the ignored repo-local `.runtime/` directory:

```text
.runtime/
  hermes-agent/
  hermes-home/
  venvs/hermes-dev/
  hermes-env.sh
```

## Scripts

- `scripts/bootstrap-hermes.sh`: clone/update Hermes and install it into `.runtime/`.
- `scripts/start-hermes-api.sh`: start the local Hermes gateway/API.
- `scripts/probe-hermes-api.sh`: probe health, capabilities, and models.

## Verified Local API

The local Hermes gateway was started and probed successfully on:

```text
http://127.0.0.1:8642
```

Verified endpoints/capabilities include:

- `GET /health`
- `GET /v1/capabilities`
- `GET /v1/models`
- `POST /v1/runs`
- `GET /v1/runs/{run_id}`
- `GET /v1/runs/{run_id}/events`
- `POST /v1/runs/{run_id}/approval`
- `POST /v1/runs/{run_id}/stop`
- `GET /v1/skills`
- `GET /v1/toolsets`

The capabilities response reports support for:

- run submission
- run status
- run events over SSE
- run stop
- approval response
- tool progress events
- approval events
- skills API
- toolsets API

This is enough for the Mac app to build the generic workflow UI around Hermes runs, progress, human review, and result display.

## App Integration Direction

The Swift app calls Hermes through a small runtime client:

```text
HermesClient
  health()
  capabilities()
  models()
  skills()
  toolsets()
  createRun()
  streamRunEvents()
  approveRun()
  stopRun()
```

The app should persist normalized run observability in Apple local persistence while preserving the raw Hermes event envelope for debugging and replay.

The first Swift implementation now checks:

- `GET /health`
- `GET /v1/capabilities`
- `GET /v1/models`
- `GET /v1/skills`
- `GET /v1/toolsets`
- `POST /v1/runs`
- `GET /v1/runs/{run_id}`
- `POST /v1/runs/{run_id}/approval`
- `POST /v1/runs/{run_id}/stop`

The Runtime tab displays this live API status when the Hermes gateway is running. If Hermes is installed but the gateway is not running, readiness can still show the CLI as installed while the Runtime tab shows the API as offline.

Observed provider-auth warnings during gateway shutdown included missing Nous authentication and OpenRouter payment/credit state. Those are provider configuration issues, not Hermes gateway failures. The app should surface them as provider-route readiness later.

## Run Submission Contract

Hermes accepts `POST /v1/runs` with:

```json
{
  "input": "User prompt or workflow instruction",
  "instructions": "Optional system-style instruction for this run",
  "session_id": "Optional session identifier",
  "model": "Optional configured model route"
}
```

Hermes returns:

```json
{
  "run_id": "run_...",
  "status": "started"
}
```

The app can then poll:

```text
GET /v1/runs/{run_id}
```

and later subscribe to:

```text
GET /v1/runs/{run_id}/events
```

The current Swift app can submit a prompt through the bottom prompt bar and poll the run status once. Full SSE streaming is the next integration step.

## Run Smoke Test

A direct `POST /v1/runs` smoke test succeeded at the API-contract layer:

```json
{
  "run_id": "run_...",
  "status": "started"
}
```

Polling `GET /v1/runs/{run_id}` also worked. The run then failed at inference setup with:

```text
No inference provider configured.
```

That means the next runtime task is provider configuration for Hermes. The app/Hermes HTTP contract is working.

## Local Ollama Provider

Development setup can configure Hermes to use local Ollama through the OpenAI-compatible Ollama endpoint:

```bash
./scripts/configure-hermes-ollama.sh qwen3.6:35b-mlx
```

This sets the repo-local Hermes config to:

```yaml
model:
  provider: custom
  default: qwen3.6:35b-mlx
  base_url: http://127.0.0.1:11435/v1
```

Local Ollama custom endpoints do not require a real API key; Hermes uses a placeholder key for local custom endpoints.

The app should prefer the shared Apple AI Ollama server on `127.0.0.1:11435`. On this machine that endpoint reports Ollama `0.31.1`, while the system Ollama app on `11434` may still be older.

Use:

```bash
./scripts/start-shared-ollama.sh
```

The shared runtime root is:

```text
/Users/golfergeek/projects/golfergeek/apple-ai-runtime
```

The runtime root can be overridden with `APPLE_AI_RUNTIME_ROOT`.
