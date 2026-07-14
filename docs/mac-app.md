# Mac App

The workflow Mac app is a SwiftUI shell under:

```text
mac-app/AppleOrchestratorAI/
```

It is intentionally small. Its job is to prove the workflow-first shell: workflow catalog, workflow runs, output review, human-in-the-loop, and advanced Hermes/Pi controls.

Apple Assistant is a separate SwiftUI app under:

```text
mac-app/AppleAssistant/
```

Apple Assistant owns the profile experience: personal, coder, writers, AI scout, golfer, and company growth. Apple Orchestrator AI should stay focused on workflows.

## Product Split

- **Apple Orchestrator AI:** workflow builder/runner, workflow catalog, Hermes runtime, Pi admin surface, workflow outputs, human-in-the-loop, legal workflow pack.
- **Apple Assistant:** voice-first profile app for personal, coder, writing, AI scout, golfer, company growth, Calendar, Reminders, and Day One.

Both apps can reuse the same file contracts, profile ideas, and voice patterns. They should not share the same user-facing purpose.

## Apple Orchestrator AI Surfaces

- **Voice:** default command surface for moving around the app and getting spoken responses.
- **Hermes:** first-pass runtime front end that probes the local Hermes API.
- **Pi:** first-pass developer/admin front end that probes Pi.

Hermes and Pi are not terminal clones. They start as health/control panels and can grow into richer local runtime/admin surfaces.

## Apple Assistant Surfaces

- **Voice:** default command surface for personal and profile requests.
- **Personal:** Calendar, Reminders, and Day One access.
- **Coder:** reads `profile.coder.efforts.v0` payloads generated from `apps/apple-orchestratorai/efforts/`.
- **Book Writer, Post Writer, AI Scout, Golfer, Company Growth:** registered profile surfaces with placeholders.

## Siri And App Intents

Apple Assistant includes first-pass App Intents so Siri can answer profile and coding-effort questions from the same file-backed effort system:

- "What's my current coding effort in Apple Assistant?"
- "What is Coder working on in Apple Assistant?"
- "How's it going in Apple Assistant?"
- "What's my assistant status in Apple Assistant?"

These intents currently read the local effort files and return spoken summaries. Later they can route through Hermes for richer natural language answers.

## Voice

The app opens on a Voice command surface. It is not intended to be a traditional left-navigation app. The top strip stays minimal:

- `Voice`

Profile and advanced runtime views should open as modal surfaces from voice commands. When dismissed, a reopen chip remains in the voice surface so the user can bring it back without navigating away. Hermes and Pi are advanced modals, not primary navigation.

The voice surface currently supports dictation-friendly text commands and spoken responses:

- `check Hermes`
- `check Pi`
- `show workflows`
- `help`

Apple Assistant supports profile commands such as:

- `show personal`
- `show coder`
- `calendar`
- `reminders`
- `write journal`

Native push-to-talk speech recognition is wired through the `Listen` button. The run script launches a development `.app` wrapper so macOS can read these privacy strings from the app bundle:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

Do not use raw `swift run` for testing microphone or speech recognition. macOS may not treat the raw executable as a privacy-described app bundle.

## Build

```bash
scripts/build-mac-app.sh
```

Build Apple Assistant:

```bash
scripts/build-apple-assistant.sh
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

Package Apple Assistant:

```bash
scripts/package-apple-assistant.sh
```

Validate the development `.app` wrapper:

```bash
scripts/check-mac-app-bundle.sh
```

Validate Apple Assistant:

```bash
scripts/check-apple-assistant-bundle.sh
```

## Run

From the repository root:

```bash
scripts/run-mac-app.sh
```

Run Apple Assistant:

```bash
scripts/run-apple-assistant.sh
```

The app locates the repository by walking upward until it finds `config/apps.json`.
