# Mac App

The first Mac app is a SwiftUI shell under:

```text
mac-app/AppleOrchestratorAI/
```

It is intentionally small. Its job is to prove that schema-driven profile surfaces can become a native app UI.

## Current Surfaces

- **Coder Efforts:** reads `profile.coder.efforts.v0` payloads generated from `apps/apple-orchestratorai/efforts/`.
- **Hermes:** first-pass runtime front end that probes the local Hermes API.
- **Pi:** first-pass developer/admin front end that probes Pi.

Hermes and Pi are not terminal clones. They start as health/control panels and can grow into richer local runtime/admin surfaces.

## Build

```bash
scripts/build-mac-app.sh
```

Or directly:

```bash
cd mac-app/AppleOrchestratorAI
swift build
```

## Run

From the repository root:

```bash
scripts/run-mac-app.sh
```

The app locates the repository by walking upward until it finds `config/apps.json`.
