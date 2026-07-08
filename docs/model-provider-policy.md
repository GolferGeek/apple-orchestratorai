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
- `cloud-required`: the workflow knowingly requires a cloud/frontier route and must not run without configured credentials and consent.

Legal client-confidential workflows should default to `local-only` or `local-first` with strict classification rules. Demo, public, writing, coding, and profile-authoring workflows can allow Codex, Google, Claude, or Ollama Cloud when explicitly configured.

Each workflow defines its own acceptable route level. Sovereignty is not an app-wide boolean. A workflow becomes sovereign by declaring:

```json
{
  "modelPolicy": {
    "sovereignty": "local-only",
    "allowedRoutes": ["local"],
    "fallbackBehavior": "fail-with-explanation"
  }
}
```

When a workflow is `local-only`, Hermes must not ask the app for cloud credentials, must not silently fall back to cloud, and must not route content to provider APIs. The only acceptable outcomes are:

- run locally
- ask the user to install/select a local model
- fail with a clear explanation

## Cost Modes

The app should be explicit that local inference is not free; it is prepaid by hardware.

Recommended cost modes:

- `prepaid-local`: use the execution Mac and local Ollama; no per-token provider bill.
- `metered-cloud`: provider charges accrue per token, per request, or subscription policy.
- `hybrid`: start with prepaid local inference and escalate only with policy and user/organization consent.

For local-first legal workflows, the default is `prepaid-local`. This is the product value: the user may have bought a high-RAM Mac, but repeated workflow attempts, source-picker reasoning, classification, synthesis, and drafting do not create a cloud token bill.

The app should never describe local inference as free. The correct user-facing language is:

- higher upfront hardware cost
- near-zero marginal inference cost
- better local control/privacy
- slower or less capable than frontier cloud on some tasks
- no surprise per-run token bill

Cloud routes should show a visible cost/trust change before use:

```json
{
  "route": "claude-subscription",
  "costMode": "metered-cloud",
  "requiresConsent": true,
  "reason": "The selected workflow allows cloud fallback, but this matter is not marked client-confidential."
}
```

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

## User-Facing Failure Language

If a local-only workflow cannot run locally:

```text
This workflow is local-only. The selected Mac does not currently have the required local model or capability. Install the required model, choose a smaller local model, or change workflow policy before using a cloud route.
```

If a local-first workflow wants to escalate:

```text
Hermes can continue locally, but a cloud route may be faster or stronger. This may use metered provider inference and may send workflow content outside this Mac. Continue with cloud?
```
