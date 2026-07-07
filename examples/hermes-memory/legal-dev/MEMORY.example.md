# Legal Dev Memory Example

## Product Role

The legal-dev profile builds and runs legal workflow prototypes using local workflow JSON, Hermes skills, MCP resources, and local observability.

## Workflow Principles

- Workflow structure lives in JSON.
- Workflow behavior lives in Hermes skills.
- The Apple app renders generic display blocks.
- Human-in-the-loop checkpoints must be explicit.
- Run state belongs in the local observability database, not workflow JSON.

## Data Boundary

- Use sample/test clients and matters by default.
- Real client or matter data must be explicitly imported into a safe local workspace.
- Do not store firm-wide databases or broad client universes locally.

## First Legal Pack

- Start with document onboarding.
- Convert one workflow first and use it to refine JSON shape.
- Convert the remaining legal workflows after the first workflow proves the pattern.
