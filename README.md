# Apple Orchestrator AI

Apple Orchestrator AI is a Mac-first, Hermes-driven workflow app.

The current phase is defining the product/runtime contracts before building the native app:

- Workflow JSON as declarative structure.
- Hermes profiles and skills as the execution model.
- Apple local persistence for metadata, run state, approvals, and observability.
- Local files and configured external sources resolved through skills.
- Provider policy handled through Hermes/Pi capabilities rather than app-specific vendor wiring.

## Current Artifacts

- `workflows/legal/document-onboarding.workflow.json`: first legal workflow definition.
- `docs/legal-document-onboarding.md`: workflow rationale and skill split.
- `docs/legal-data-and-file-model.md`: Apple local data/file model.
- `docs/model-provider-policy.md`: local/cloud/Codex/Google/Claude provider policy.
- `docs/hermes-runtime.md`: Hermes runtime/API notes verified in this checkout.
- `docs/ollama-mlx-models.md`: local Ollama Apple-optimized model policy.
- `docs/mac-deployment.md`: deployment target and installer plan.
- `docs/first-launch-setup.md`: first-launch setup contract.
- `runtime/runtime-manifest.json`: expected bundled/runtime-managed components.
- `scripts/check-mac-readiness.sh`: local readiness check.
- `scripts/build-dmg.sh`: future DMG packaging entry point.
- `scripts/run-mac-app.sh`: runs the SwiftUI app from this checkout.
- `scripts/bootstrap-hermes.sh`: installs/updates Hermes under `.runtime/`.
- `scripts/start-hermes-api.sh`: starts the local Hermes API after bootstrap.
- `scripts/probe-hermes-api.sh`: probes the local Hermes API health/capabilities.

## Local Development

Build the Mac app skeleton:

```bash
swift build
```

Run readiness checks:

```bash
./scripts/check-mac-readiness.sh
```

Run the SwiftUI app:

```bash
./scripts/run-mac-app.sh
```

Start and probe the Hermes API:

```bash
./scripts/start-hermes-api.sh
./scripts/probe-hermes-api.sh
```

Start or check the shared Ollama runtime:

```bash
./scripts/start-shared-ollama.sh
```

Configure Hermes to use local Ollama:

```bash
./scripts/configure-hermes-ollama.sh qwen3.6:35b-a3b-nvfp4
```

Bootstrap Hermes into this repo's ignored `.runtime/` directory:

```bash
./scripts/bootstrap-hermes.sh
```
