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

Do not hard-code a single model in workflow JSON. Workflow JSON can declare model needs as profiles:

```json
{
  "model_profile": "legal_reasoning"
}
```

Hermes maps profiles to installed Ollama models.

## Missing Model Behavior

If a required model/profile is missing, Hermes should emit a display response asking the user to install or select a model.
