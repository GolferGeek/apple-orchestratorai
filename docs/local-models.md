# Local Models

Apple Orchestrator AI Local uses local models by default.

## Product Rule

Local means local:

- no cloud model path by default
- no frontier model dependency
- no Apple Private Cloud dependency for this app
- Ollama is the local model provider

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

## MLX Direction

Ollama's MLX support on Apple Silicon should be preferred where available because this product is Mac-first.

The development baseline is:

```text
Ollama >= 0.31.1
```

This matters because Ollama 0.31.1 includes the faster Gemma 4 MLX path on Apple Silicon and updated MLX engine support. Older versions may run some MLX models, but they should not be treated as the supported baseline for this project.

Local scripts:

```bash
scripts/check-ollama-mlx.sh
scripts/upgrade-ollama-macos.sh
scripts/start-ollama-mlx.sh
scripts/pull-mlx-models.sh core
```

By default, `scripts/upgrade-ollama-macos.sh` installs a project-local Ollama app under `.runtime/ollama/Ollama.app` and runs it on `127.0.0.1:11435`. This avoids replacing the user's global `/Applications/Ollama.app`.

To replace the global app instead, run:

```bash
INSTALL_SCOPE=app scripts/upgrade-ollama-macos.sh
```

If the app-scope install reports that `/Applications` is not writable, use the official Ollama updater or rerun the script with permissions that can replace `/Applications/Ollama.app`.

Recommended default MLX model set:

```text
gemma4:e2b-mlx
gemma4:e4b-mlx
gemma4:12b-mlx
qwen3.6:27b-mlx
```

Use cases:

- `gemma4:e2b-mlx`: very fast smoke tests, lightweight routing, simple classification.
- `gemma4:e4b-mlx`: fast local assistant, smaller workflow steps, inexpensive iteration.
- `gemma4:12b-mlx`: default local reasoning model for early workflows.
- `qwen3.6:27b-mlx`: agentic coding, repository reasoning, workflow-building, and complex Hermes execution.

Optional workstation tier:

```text
gemma4:26b-mlx
```

Optional full tier:

```text
gemma4:e2b-mlx
gemma4:e4b-mlx
gemma4:12b-mlx
gemma4:26b-mlx
gemma4:31b-mlx
qwen3.6:27b-mlx
qwen3.6:35b-mlx
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
