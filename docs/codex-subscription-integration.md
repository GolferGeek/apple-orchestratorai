# Codex Subscription Integration

Apple Orchestrator AI should distinguish three different inference routes:

- **Local route:** Ollama on the Mac, preferred for local-only workflows.
- **Codex subscription route:** Codex-authenticated agent turns through the user's ChatGPT/Codex subscription.
- **OpenAI API route:** direct OpenAI Platform API calls, billed through API usage.

The Codex subscription route is the one we want when the user says, "use my Codex subscription instead of API costs." It should not be modeled as an `OPENAI_API_KEY`.

## Hermes Options

Hermes has two relevant Codex paths.

First, Hermes exposes an `OpenAI Codex` auth provider. In this project runtime, `hermes status` shows that provider separately from OpenAI API keys and stores its auth under:

```text
.runtime/hermes-home/auth.json
```

That file is runtime state and must not be committed.

Second, the bundled Hermes docs describe a Codex app-server runtime. That path lets Hermes hand OpenAI/Codex turns to the Codex CLI app-server, using Codex's ChatGPT subscription auth and Codex's own agent surfaces instead of a generic OpenAI API key.

## Current Local State

Current checks on this machine:

- Codex CLI exists at `/Users/golfergeek/.npm-global/bin/codex`.
- Codex CLI reports version `0.38.0`.
- `~/.codex/auth.json` exists, so the user's normal Codex CLI appears to have local auth state.
- Hermes is not yet logged into its project-local `OpenAI Codex` auth provider.
- The bundled Hermes Codex app-server runtime docs say Codex CLI `0.130.0` or newer is required, so the installed CLI likely needs to be upgraded before app-server runtime testing.

Do not print or commit the contents of `~/.codex/auth.json` or `.runtime/hermes-home/auth.json`.

## Setup Intention

For subscription-backed Codex use:

```bash
codex login
source .runtime/hermes-env.sh
hermes auth add openai-codex --type oauth
```

For Hermes app-server runtime testing, first upgrade Codex CLI if needed:

```bash
npm install -g @openai/codex
codex --version
```

Then enable the Codex runtime in Hermes using the Hermes-supported runtime selector or config:

```yaml
model:
  openai_runtime: codex_app_server
```

The exact enablement should stay behind an app/runtime setting, not a global default.

## Profile Policy

Subscription-backed Codex should be profile and workflow scoped.

Recommended defaults:

- `coder`: allow Codex subscription route.
- `company-growth`: allow Codex subscription route when the user opts into cloud inference for business reasoning.
- `ai-scout`: allow Codex subscription route when current research or tool use benefits from it.
- `book-writer` and `post-writer`: optional, based on privacy preference.
- `legal-dev`: default to local or explicitly approved routes; do not silently send legal matter content to Codex.
- `personal`: default to local/private; ask before using cloud inference for sensitive personal context.

This preserves the local-first product promise while still letting the user intentionally spend included Codex capacity where it creates value.

## Product Rule

If Hermes is configured as a plain OpenAI provider with an API key, that is OpenAI Platform API usage and should be treated as API-billed.

If the intent is to use the user's subscription, route through Hermes `openai-codex`, the Codex CLI, or the Codex app-server runtime. The Apple app should expose that as a distinct inference option, such as:

```text
Local only | Codex subscription | API/Frontier
```
