# Mac Deployment

The end state is a signed and notarized Mac distribution that installs the native Apple Orchestrator AI app and prepares the local Hermes runtime.

## Distribution Target

Primary target:

- Signed `Apple Orchestrator AI.app`
- Notarized DMG for direct installation

Secondary target:

- PKG installer for enterprise deployment if privileged install steps, launch agents, shared runtime services, or managed-device rollout become necessary.

Mac App Store is not the first target because the app depends on local runtimes, local model management, provider credentials, user-selected file roots, and potentially bundled CLI tools.

## Installed Components

The installed app should include or manage:

- Native SwiftUI Mac app
- Hermes runtime
- Pi runtime, if retained
- Default workflow definitions
- Default shared skill pack
- Default legal shared skill pack
- `legal-dev` profile template
- Runtime health and setup scripts
- First-launch setup wizard

The app should not require the user to run terminal commands for normal setup.

During development, `scripts/bootstrap-hermes.sh` installs Hermes under the repo-local `.runtime/` directory. Production packaging should either bundle an approved Hermes runtime or run the same bootstrap/update logic through a signed app-controlled setup flow.

## Runtime Layout

Recommended app support layout:

```text
~/Library/Application Support/Apple Orchestrator AI/
  config/
  workflows/
    legal/
  skills/
    shared/
    legal-shared/
    legal-workflows/
  profiles/
    legal-dev/
  runtime/
    hermes/
    pi/
  runs/
  outputs/
  logs/
```

User-selected client/matter file roots may live outside this folder. The app should store security-scoped bookmarks and pass allowed roots to Hermes through the app-owned service contract.

## Installer Responsibilities

The installer should:

- Install the Mac app.
- Place bundled workflow and skill templates in the app bundle.
- Prepare an app support directory on first launch.
- Avoid storing secrets in files.
- Defer provider credentials to the first-launch setup wizard and Apple Keychain.

## First-Launch Responsibilities

First launch should:

- Create or migrate the Apple local database.
- Create app support folders.
- Install or update bundled workflow definitions.
- Install or update bundled skills.
- Create the `legal-dev` profile if missing.
- Discover Hermes and Pi runtime availability.
- Discover local Ollama availability and installed models.
- Ask Hermes for provider route capabilities.
- Prompt for optional provider credentials only when useful.
- Run a health check.

## Build Pipeline

Initial local packaging path:

```text
swift build/archive
codesign
notarytool submit
stapler staple
hdiutil create DMG
```

The current repo only has contracts and scripts. The packaging script is intentionally a scaffold until the Swift app target exists.
