# Model Provider Policy

Apple Orchestrator AI should support multiple inference providers without making any one provider the center of the architecture. Hermes skills ask for inference; the active profile, workflow, graph, skill, organization settings, and machine capability decide which providers are allowed.

Hermes and Pi should absorb as much provider complexity as possible. The Apple app should not need separate UI flows for every model vendor. The app should ask Hermes what routes are available, what credentials are missing, and what a workflow is allowed to use.

## Provider Routes

Initial provider routes:

- `local`: local Ollama on the execution Mac.
- `ollama-cloud`: Ollama Cloud using the user's or organization's API key.
- `codex-subscription`: Codex through the user's authenticated Codex subscription where available.
- `google-subscription`: Google model access using the user's or organization's API key.
- `claude-subscription`: Anthropic/Claude access using the user's or organization's API key.

The app should treat cloud providers as optional configured routes. A missing key is not an app failure; it only means that provider is unavailable for workflows that allow it.

## Credential Model

Use bring-your-own credentials by default:

- Store provider credentials in the user's Apple Keychain.
- Never store provider secrets inside workflow JSON.
- Workflow JSON may name allowed provider routes, but not the secret values.
- Organization defaults may enable or disable provider routes.
- A workflow can require explicit user confirmation before sending data to any cloud route.

The preferred app-facing contract is capability-based, not vendor-form based:

```json
{
  "providerRoutes": [
    {
      "id": "local",
      "status": "available",
      "managedBy": "hermes"
    },
    {
      "id": "claude-subscription",
      "status": "missing-credential",
      "managedBy": "hermes",
      "requiredCredential": "anthropic-api-key"
    }
  ]
}
```

If Hermes or Pi can configure a provider from CLI/SDK state, the app should consume that state instead of duplicating it.

## Sovereignty Modes

Recommended workflow-level modes:

- `local-only`: only local Ollama may receive workflow content.
- `local-first`: use local Ollama by default; ask before cloud fallback.
- `cloud-allowed`: cloud routes are allowed if credentials exist and the data classification permits them.
- `cloud-preferred`: cloud routes may be preferred for non-confidential workflows when the user or organization configures them.

Legal client-confidential workflows should default to `local-only` or `local-first` with strict classification rules. Demo, public, writing, coding, and profile-authoring workflows can allow Codex, Google, Claude, or Ollama Cloud when explicitly configured.

## Runtime Selection

Provider selection should evaluate these layers in order:

1. Skill policy
2. Graph policy
3. Workflow policy
4. Profile policy
5. Organization/user settings
6. Mac capability check
7. Available credentials

Narrower scopes can only restrict broader scopes unless the user or organization explicitly permits escalation.

Hermes should be the primary policy evaluator. The Apple app can show the result, ask for missing credentials or consent, and persist observability, but it should not reimplement model routing logic unless Hermes is unavailable.

## Capability Check

Before launch, the app should check:

- Whether Ollama is installed and running.
- Which local models are installed.
- Whether the Mac appears capable of running the required local model.
- Whether cloud provider credentials exist for any allowed fallback route.
- Whether the workflow's data classification permits cloud use.

If a workflow is local-only and the Mac cannot run the required model, the app should fail with a clear explanation instead of silently using a cloud provider.
