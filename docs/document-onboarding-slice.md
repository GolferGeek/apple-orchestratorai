# Document Onboarding Slice

Document onboarding should be the first workflow converted from OrchestratorAI Local.

## Why This Workflow

It is the best first slice because it tests:

- Pi workflow-agent structure
- project-agent delegation
- dynamic agent promotion
- local file resource
- document ingestion
- run state
- live updates
- human-in-the-loop review
- output rendering
- artifact creation

It is simpler than contract review while still exercising the architecture.

## First Pi Workflow Goal

Create one Pi-native workflow package:

```text
.pi/agents/legal-document-onboarding-coordinator.md
.pi/skills/legal-*/SKILL.md
.pi/prompts/document-onboarding.md
.pi/extensions/workflow-tools/index.ts
```

It should include:

- one coordinator agent
- source, intake, metadata, routing, specialist, synthesis, HITL, report, and validation agents
- required legal and shared skills
- workflow extension tools for events, source resolution, HITL, artifacts, and structured output
- project-agent delegation for work teams
- dynamic agent spawning for approved one-run specialist roles
- human checkpoint
- expected outputs

JSON may exist as catalog metadata or fixture input, but it is not the thing Pi executes.

## First Runtime Goal

The app should be able to:

1. discover the Pi workflow prompt/agent
2. show it in the workflow list with a user-facing explanation
3. start a run through Pi with the coordinator agent
4. receive progress events
5. show a human review task
6. accept an approval/reject action
7. display a Markdown output
8. persist run state locally

The first output can be Markdown for simplicity, but the architecture should allow Pi skills and extension tools to update outputs or generate files/artifacts directly.

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

Do not convert all 17 workflows until document onboarding proves the Pi agent, skill, project-agent, dynamic-agent, event, HITL, and output pattern.
