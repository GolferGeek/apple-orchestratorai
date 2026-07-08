# Local Models

Apple Orchestrator AI Local uses local models by default.

## Product Rule

Local means local:

- no cloud model path by default
- no frontier model dependency
- no Apple Private Cloud dependency for this app
- Ollama is the local model provider

Local inference is best described as prepaid, not free. The user pays for the Mac, memory, storage, electricity, and time. The benefit is near-zero marginal inference cost after that purchase, plus local control and no surprise per-run provider bill.

## Model Host

The Mac runs Ollama. iPhone and iPad do not run heavy workflow models.

Hermes should route model calls by task type:

- fast classification
- workflow planning
- legal reasoning
- document summarization
- drafting
- tool/coding-style reasoning
- output formatting

## Initial Model Classes

The exact model names should remain configurable, but the classes matter:

- fast small model
- general legal reasoning model
- larger reasoning model
- tool-heavy/coding model
- embedding model if local retrieval/indexing is needed

## Apple-Optimized Direction

Ollama's Apple Silicon optimized model paths should be preferred where available because this product is Mac-first. The actual tag names matter: the installed Qwen models use explicit `nvfp4` tags, and the installed Gemma models use explicit `-mlx` tags.

The development baseline is:

```text
Ollama >= 0.31.1
```

This matters because Ollama 0.31.1 includes the faster Gemma 4 MLX path on Apple Silicon and updated local engine support. Older versions may run some models, but they should not be treated as the supported baseline for this project.

Local scripts:

```bash
scripts/check-ollama-mlx.sh
scripts/upgrade-ollama-macos.sh
scripts/start-ollama-mlx.sh
scripts/pull-mlx-models.sh core
```

By default, this app should use the shared Apple AI runtime on `127.0.0.1:11435`, currently rooted at `/Users/golfergeek/projects/golfergeek/apple-ai-runtime`. That keeps this app, the assistant app, and future Apple-local tooling on one modern Ollama server instead of duplicating model stores.

To replace the global app instead, run:

```bash
INSTALL_SCOPE=app scripts/upgrade-ollama-macos.sh
```

If the app-scope install reports that `/Applications` is not writable, use the official Ollama updater or rerun the script with permissions that can replace `/Applications/Ollama.app`.

Recommended default Apple-optimized model set:

```text
qwen3.6:35b-a3b-nvfp4
qwen3.6:35b-a3b-coding-nvfp4
gemma4:e2b-mlx
gemma4:e4b-mlx
```

Use cases:

- `qwen3.6:35b-a3b-nvfp4`: strong local legal/workflow reasoning default.
- `qwen3.6:35b-a3b-coding-nvfp4`: coding, repository reasoning, workflow-building, and tool-heavy tasks.
- `gemma4:e4b-mlx`: fast local assistant, smaller workflow steps, inexpensive iteration.
- `gemma4:e2b-mlx`: very fast smoke tests, lightweight routing, simple classification.

Optional workstation tier:

```text
deepseek-r1:70b
```

Optional full tier:

```text
qwen3.6:35b-a3b-nvfp4
qwen3.6:35b-a3b-coding-nvfp4
gemma4:e2b-mlx
gemma4:e4b-mlx
deepseek-r1:70b
gpt-oss:20b
```

Do not make the full tier the default. It is large and should be a conscious install choice.

Do not hard-code a single model in workflow JSON. Workflow JSON can declare model needs as profiles:

```json
{
  "model_profile": "legal_reasoning"
}
```

Hermes maps profiles to installed Ollama models.

## Missing Model Behavior

If a required model/profile is missing, Hermes should emit a display response asking the user to install or select a model.

## Hardware Economics

A high-RAM Mac changes the marginal economics of workflows:

- repeated workflow runs do not create a per-token cloud bill
- source-picker reasoning and MCP planning can happen locally
- legal document classification/synthesis can be tested many times without metered API spend
- long local runs are slower but predictable in cost

The app should surface this as a tradeoff, not a miracle:

```text
Local mode uses this Mac. It may be slower, but it does not use metered cloud inference.
```

For organizations without strong enough Macs, workflow policy can allow `ollama-cloud`, `codex-subscription`, `google-subscription`, or `claude-subscription`, subject to data classification and consent.
