# Schema Strategy

Schemas are part of the intention-driven build system.

## Required Schemas

The project should define schemas for:

- workflow JSON
- workflow pack manifest
- profile manifest
- profile surface
- app effort metadata
- app effort questions
- app registry
- Hermes display response
- Hermes view block
- Hermes event
- Hermes action
- output metadata
- artifact metadata
- local runtime state
- MCP resource binding

## Source of Truth

Use JSON Schema for cross-runtime contracts where possible. Swift models, TypeScript types, tests, and fixtures should be generated from or checked against these schemas when practical.

## Versioning

Every contract should include a schema version:

```json
{
  "schema_version": "0.1"
}
```

Compatibility should be explicit. The Apple app should reject or warn on unsupported major versions.

## Validation Rule

No workflow JSON file should be considered runnable until it validates.

No Hermes display response should be rendered as trusted UI until it validates or passes a tolerant decoder.

Unknown view blocks may be ignored or rendered as unsupported; they should not crash the app.
