# Mac App

The first Mac app is a SwiftUI shell under:

```text
mac-app/AppleOrchestratorAI/
```

It is intentionally small. Its job is to prove that schema-driven profile surfaces can become a native app UI.

## Current Surfaces

- **Voice:** default command surface for moving around the app and getting spoken responses.
- **Coder Efforts:** reads `profile.coder.efforts.v0` payloads generated from `apps/apple-orchestratorai/efforts/`.
- **Hermes:** first-pass runtime front end that probes the local Hermes API.
- **Pi:** first-pass developer/admin front end that probes Pi.

Hermes and Pi are not terminal clones. They start as health/control panels and can grow into richer local runtime/admin surfaces.

## Siri And App Intents

The app includes first-pass App Intents so Siri can answer effort questions from the same file-backed effort system:

- "What's my current effort in Apple Orchestrator AI?"
- "What am I working on in Apple Orchestrator AI?"
- "How's it going in Apple Orchestrator AI?"
- "What's my effort status in Apple Orchestrator AI?"

These intents currently read the local effort files and return spoken summaries. Later they can route through Hermes for richer natural language answers.

## Voice

The app opens on a Voice command surface. It currently supports dictation-friendly text commands and spoken responses:

- `show coder efforts`
- `check Hermes`
- `check Pi`
- `reload efforts`
- `help`

Native push-to-talk speech recognition is wired through the `Listen` button. Development builds embed these privacy strings into the executable Info.plist section:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

When the app moves from Swift Package executable to an Xcode app bundle, those keys should move into the app target's bundled `Info.plist`.

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
