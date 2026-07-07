# Document Onboarding Slice

Document onboarding should be the first workflow converted from OrchestratorAI Local.

## Why This Workflow

It is the best first slice because it tests:

- workflow JSON structure
- local file resource
- document ingestion
- run state
- live updates
- human-in-the-loop review
- output rendering
- artifact creation

It is simpler than contract review while still exercising the architecture.

## First Workflow JSON Goal

Create one workflow JSON file:

```text
workflow-packs/legal/workflows/document-onboarding.workflow.json
```

It should include:

- identity
- lifecycle status
- source references to OrchestratorAI Local
- required skills
- required MCP resources
- graph nodes
- graph edges
- human checkpoint
- expected outputs
- render hints

## First Runtime Goal

The app should be able to:

1. discover the workflow JSON
2. show it in the workflow list with a user-facing explanation
3. start a run through Hermes or a Hermes mock
4. receive progress events
5. show a human review task
6. accept an approval/reject action
7. display a Markdown output
8. persist run state locally

The first output can be Markdown for simplicity, but the architecture should allow Hermes skills to update outputs or generate files/artifacts directly.

The first slice should also prove workflow explanation:

- list document onboarding in the workflow catalog
- explain what it is for
- explain at least one subgraph or work unit
- let the user ask "tell me more"
- return a structured refinement proposal for one simple change

## Source Material

Initial source repo:

```text
/Users/golfergeek/projects/orchAI/orchestratorai-local
```

Likely source files:

```text
apps/api/src/legal/workflows/document-onboarding/
tests/integration/fixtures/flagship/document-onboarding.fixture.json
docs/efforts/archive/document-onboarding/
```

## Conversion Rule

Do not convert all 17 workflows until document onboarding proves the JSON shape.
