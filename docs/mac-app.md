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

The app opens on a Voice command surface. It is not intended to be a traditional left-navigation app. The top strip only exposes the running surfaces that should always be reachable:

- `Voice`
- `Hermes`
- `Pi`

Profile-specific views should open as modal surfaces from voice commands. When dismissed, a reopen chip remains in the voice surface so the user can bring it back without navigating away.

The voice surface currently supports dictation-friendly text commands and spoken responses:

- `show coder efforts`
- `show personal`
- `what is on my calendar`
- `what reminders are open`
- `write journal <entry text>`
- `check Hermes`
- `check Pi`
- `reload efforts`
- `help`

## Personal Integrations

The first personal modal connects:

- Calendar through EventKit.
- Reminders through EventKit.
- Day One through the local `dayone` CLI, with `dayone2` fallback.

The development app bundle includes these privacy keys:

- `NSCalendarsFullAccessUsageDescription`
- `NSCalendarsUsageDescription`
- `NSRemindersFullAccessUsageDescription`
- `NSRemindersUsageDescription`

Day One requires the CLI to be installed from the Day One Mac app. Day One's current official CLI command is `dayone`; older installs may still provide `dayone2`.

Native push-to-talk speech recognition is wired through the `Listen` button. The run script launches a development `.app` wrapper so macOS can read these privacy strings from the app bundle:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

Do not use raw `swift run` for testing microphone or speech recognition. macOS may not treat the raw executable as a privacy-described app bundle.

## Build

```bash
scripts/build-mac-app.sh
```

Or directly:

```bash
cd mac-app/AppleOrchestratorAI
swift build
```

To create the development `.app` wrapper:

```bash
scripts/package-mac-app.sh
```

Validate the development `.app` wrapper:

```bash
scripts/check-mac-app-bundle.sh
```

## Run

From the repository root:

```bash
scripts/run-mac-app.sh
```

The app locates the repository by walking upward until it finds `config/apps.json`.
