# Profile Contract

Profiles are domain modes for Hermes and the Apple app. They define routing, memory boundaries, inference choices, tool permissions, work intake behavior, runtime scopes, and generic output expectations.

Profiles do not store live memory, credentials, run history, or private files. Those belong in runtime state and app-managed storage.

## Contract Shape

Profile ids are stable lowercase kebab-case. Profile status is intentionally simple:

- `active`
- `inactive`

Semantic versioning is allowed for compatibility tracking, but the user does not need to manage it manually.

```json
{
  "schemaVersion": "0.1.0",
  "id": "coder",
  "displayName": "Coder",
  "version": "0.1.0",
  "status": "active",
  "purpose": "Coordinate software efforts across the user's apps and hand implementation work to Codex.",
  "routing": {
    "triggers": ["code", "repo", "Codex", "build this", "test failure"],
    "userIntents": ["coding", "implementation", "debugging", "app building"]
  },
  "tasks": [
    "Show current coding efforts.",
    "Create a new coding effort from an intention file.",
    "Turn an intention into a Codex work packet.",
    "Ask Codex to build or modify source.",
    "Review what Codex changed.",
    "Summarize build and test results."
  ],
  "memoryPolicy": {
    "privacyLevel": "development",
    "commitLiveMemory": false,
    "allowedMemory": [
      "approved architecture decisions",
      "app-specific coding preferences",
      "effort conventions",
      "build and test patterns"
    ],
    "disallowedMemory": [
      "credentials",
      "private customer data",
      "unapproved personal facts",
      "live session transcripts unless explicitly promoted"
    ]
  },
  "inferencePolicy": {
    "defaultRoute": "codex-subscription",
    "allowedRoutes": ["ollama", "ollama-cloud", "codex-subscription"],
    "requiresApprovalFor": ["ollama-cloud"]
  },
  "toolPolicy": {
    "canUseHermesSkills": true,
    "canUseMcp": true,
    "canUsePi": true,
    "canUseCodex": true,
    "canUseExternalResearch": true,
    "canModifySource": true,
    "requiresApprovalForTools": [
      "filesystem-write",
      "network-external",
      "credential-access",
      "runtime-upgrade"
    ]
  },
  "workIntake": {
    "enabled": true,
    "inboxScope": "app",
    "acceptedEffortTarget": "current",
    "clearEnoughPolicy": "accept-and-create-current-effort",
    "unclearPolicy": "write-blocking-questions-without-creating-effort",
    "deferrablePolicy": "create-or-move-to-future",
    "effortStates": ["current", "future", "archive"]
  },
  "runtime": {
    "stateScope": "profile",
    "memoryScope": "coder",
    "workspaceScope": "coder"
  },
  "outputs": [
    { "type": "markdown", "label": "Summary" },
    { "type": "json", "label": "Structured Result" },
    { "type": "file-bundle", "label": "Artifacts" }
  ]
}
```

## Inference Routes

V1 supports these product routes:

- `ollama`: local Ollama on the execution Mac.
- `ollama-cloud`: Ollama Cloud, when explicitly allowed.
- `codex-subscription`: Codex/ChatGPT subscription-backed inference through Hermes `openai-codex`, Codex CLI, or Codex app-server runtime.

Do not model Codex subscription use as an OpenAI API key. Direct OpenAI API usage is outside the v1 base contract unless a later enterprise build adds it.

Recommended defaults:

| Profile | Default route | Allowed routes |
|---|---|---|
| `coder` | `codex-subscription` | `ollama`, `ollama-cloud`, `codex-subscription` |
| `company-growth` | `ollama` | `ollama`, `ollama-cloud`, `codex-subscription` |
| `ai-scout` | `ollama` | `ollama`, `ollama-cloud`, `codex-subscription` |
| `personal` | `ollama` | `ollama`, `codex-subscription` with approval |
| `legal-dev` | `ollama` | `ollama`, `codex-subscription` with explicit approval |
| `book-writer` | `ollama` | `ollama`, `ollama-cloud`, `codex-subscription` |
| `post-writer` | `ollama` | `ollama`, `ollama-cloud`, `codex-subscription` |
| `golfer` | `ollama` | `ollama` |

## Runtime And Device Policy

The device policy is app-level, but profiles must be compatible with it:

- Mac Studio is the execution authority and admin controller.
- iPhone and iPad are remote controllers.
- MacBook Pro has no v1 product role unless later added as a controller.

The execution authority owns Hermes, Ollama, Codex subscription auth, profile runtime state, and database writes. Controllers submit work, answer questions, approve human tasks, steer runs, and view outputs.

## Persistence Policy

V1 uses Apple persistence:

- iCloud Drive or app-managed files for effort files, workflow files, artifacts, and output packages.
- SwiftData/Core Data/CloudKit where Apple-native records and sync are useful.
- No MySQL or Supabase in the base product.

Mac Studio remains the runtime authority even when Apple sync is used.
