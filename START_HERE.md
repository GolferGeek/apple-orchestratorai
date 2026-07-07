# Apple Orchestrator AI — Start Here

This is the entry file for the project. Treat it like the course syllabus and project map.

The goal is to build a Mac-first local orchestration app on top of Hermes:

- workflow structure lives in local JSON files
- workflow behavior lives in Hermes skills
- external systems are reached through MCP tools/connectors
- Ollama runs local models on the Mac
- Pi is available as an optional developer/admin harness for building and repairing workflows, skills, prompts, and integrations
- the local database stores runs, events, human tasks, outputs, and audit state
- the Apple app renders generic Hermes display responses, not custom UI per workflow

## Reading Order

1. [Product Brief](docs/product-brief.md)
2. [Architecture](docs/architecture.md)
3. [Workflow JSON](docs/workflow-json.md)
4. [Hermes App Contract](docs/hermes-app-contract.md)
5. [Local Runtime State](docs/local-runtime-state.md)
6. [MCP Resources](docs/mcp-resources.md)
7. [Generic Apple UI](docs/generic-apple-ui.md)
8. [Authentication and Trust](docs/authentication-and-trust.md)
9. [Hermes Bundle](docs/hermes-bundle.md)
10. [Local Models](docs/local-models.md)
11. [Pi Runtime](docs/pi-runtime.md)
12. [Hermes Profiles](docs/hermes-profiles.md)
13. [Profile Contract](docs/profile-contract.md)
14. [App Effort System](docs/effort-system.md)
15. [Mac App](docs/mac-app.md)
16. [Schema Strategy](docs/schema-strategy.md)
17. [Legal Workflow Pack](docs/legal-workflow-pack.md)
18. [Document Onboarding Slice](docs/document-onboarding-slice.md)
19. [Testing Strategy](docs/testing-strategy.md)
20. [Build Plan](docs/build-plan.md)
21. [Iterative Build Method](docs/iterative-build-method.md)
22. [Open Questions](docs/open-questions.md)

## First Build Target

The first useful prototype should prove:

1. The Mac app can discover workflow JSON files.
2. The Mac app can start a workflow through Hermes.
3. Hermes can emit generic display JSON.
4. The app can receive live updates through an event stream.
5. The app can persist run state in a local observability database.
6. The app can render active/completed/blocked/human-in-loop runs without custom workflow UI.
7. One legal workflow can run against a local test matter.
8. The Mac app can expose a small admin/workbench surface for Pi without making Pi part of the normal workflow UI.
9. The Mac app can route requests to the right Hermes profile.
10. The Mac app can render the first schema-driven profile surface for coder efforts.
11. The Mac app can answer first-pass Siri/App Intent questions about current efforts and effort status.

Run the current Mac app shell with:

```bash
scripts/run-mac-app.sh
```

## Non-Goals for the First Build

- No cloud model path.
- No custom UI per workflow.
- No enterprise server.
- No firm-wide database mirror.
- No iPad-first execution.
- No iPhone model execution.

## Project Rule

If a new workflow requires a new hard-coded Apple screen, the architecture has drifted. New workflow behavior should come from workflow JSON, Hermes skills, MCP tools, and generic display blocks.

## Development Method

This project should be built repeatedly from intention files and source files. Each build attempt should improve the intention files, schemas, examples, and implementation until the result converges on the desired app.

The intended loop is:

```text
write intention
  -> generate/build implementation
  -> inspect result
  -> improve intention and source files
  -> rebuild
```

The closer the intention files get, the closer the project should get to a one-shot build.
