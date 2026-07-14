# Ollama Apple-Optimized Models

Apple Orchestrator AI should prefer explicit Ollama Apple-optimized model tags for local execution on Apple Silicon. Use explicit `-mlx` tags for this project.

The shared Apple AI Ollama endpoint is:

```text
http://127.0.0.1:11435/v1
```

The ordinary system Ollama endpoint on `11434` may also exist, but this app should use the shared runtime on `11435` unless explicitly overridden.

## Installed Explicit Optimized Tags

These tags are installed on the shared Ollama instance at `127.0.0.1:11435`:

```text
qwen3.6:35b-mlx
context length: 262144
usage size: 22GB
capabilities: completion, vision, thinking, tools

qwen3.6:27b-mlx
context length: 262144
usage size: 20GB
capabilities: completion, vision, thinking, tools

gemma4:e4b-mlx
architecture: gemma4
parameters: 8.1B
context length: 131072
requires: 0.31.0
capabilities: completion, tools, thinking

gemma4:e2b-mlx
architecture: gemma4
parameters: 5.2B
context length: 131072
requires: 0.31.0
capabilities: completion, tools, thinking
```

Plain tags such as `gemma4:e4b`, `gemma4:e2b`, and `qwen3.6:latest` are not the explicit optimized tags for this project and should not be used as runtime defaults.

## Local Model Policy

Recommended defaults:

- Strong legal/workflow default: `qwen3.6:35b-mlx`
- Lighter Qwen fallback: `qwen3.6:27b-mlx`
- Lighter local fallback: `gemma4:e4b-mlx`
- Small local fallback: `gemma4:e2b-mlx`

The workflow and profile policy should continue to express routes as `local`, not as raw model names. The runtime resolves the actual model route.

## Runtime Version Note

The shared Ollama server on `127.0.0.1:11435` currently reports:

```text
0.31.1
```

The PATH CLI may still be `/Applications/Ollama.app/Contents/Resources/ollama` and may report an older client version. The server version on `11435` is the version that matters for Hermes inference in this app.

The Gemma MLX tags declare `requires: 0.31.0`, so the shared `0.31.1` runtime is sufficient for the installed Gemma MLX tags.

## Notes

Do not silently fall back from local Ollama to cloud providers. If a workflow is local-only and the selected local model is missing or too large for the Mac, the app should block the run with a clear explanation.
