# First-Launch Setup

The first-launch setup wizard should make the Mac usable without forcing the user through vendor-specific configuration screens.

## Setup Contract

The Apple app owns:

- User consent
- Apple local database setup
- Keychain storage
- Security-scoped file access
- UI state and observability
- Health-check presentation

Hermes owns:

- Workflow discovery
- Skill discovery
- Profile discovery
- Provider route discovery
- Runtime model/provider policy evaluation
- Run execution and event streaming

Pi owns:

- Optional coding-harness/admin capabilities if retained
- Runtime maintenance tasks where it is the better abstraction

## Setup Steps

1. Create app support directories.
2. Initialize Apple local persistence.
3. Copy bundled workflow definitions if missing or older.
4. Copy bundled skill packs if missing or older.
5. Create the `legal-dev` profile from the bundled template if missing.
6. Start or discover Hermes.
7. Start or discover Pi if enabled.
8. Check Ollama local availability.
9. Ask Hermes for provider route capabilities.
10. Ask for missing optional credentials only if the user enables those routes.
11. Run a workflow/runtime health check.

## Provider Setup

Provider setup should be capability-driven:

```json
{
  "route": "claude-subscription",
  "status": "missing-credential",
  "requiredCredential": "anthropic-api-key",
  "managedBy": "hermes"
}
```

The app should store secrets in Apple Keychain and tell Hermes which named credential is available. Workflow JSON should never contain secrets.

## Local-Only Guardrail

If a workflow is `local-only`, setup can report that cloud routes are configured, but runtime must not send workflow content to those routes.

If the Mac cannot run the required local model, the app should say so clearly and block the workflow unless the workflow explicitly allows cloud fallback.

## Health Check Output

The health check should return display-shaped JSON so the SwiftUI app can show it without custom screens:

```json
{
  "status": "needs-attention",
  "checks": [
    {
      "id": "hermes-runtime",
      "label": "Hermes Runtime",
      "status": "ok"
    },
    {
      "id": "ollama-local",
      "label": "Local Ollama",
      "status": "missing"
    }
  ],
  "actions": [
    {
      "id": "configure-ollama-cloud",
      "label": "Add Ollama Cloud key",
      "kind": "credential"
    }
  ]
}
```
