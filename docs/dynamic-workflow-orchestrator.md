# Dynamic Workflow Orchestrator

Apple Orchestrator AI should support two orchestration modes.

## Specific Workflow Agents

Specific workflow agents own known workflows.

Examples:

- `legal-document-onboarding-coordinator`
- future contract review coordinator
- future privilege review coordinator
- future diligence coordinator

Use a specific workflow agent when the app already knows the workflow shape, required HITL checkpoint, expected outputs, and likely specialist lanes.

Specific workflow agents may run after launch because their safety and output contracts are known.

## Discovery Orchestrator

`workflow-discovery-orchestrator` handles non-standard requests.

It should answer:

- What is the user asking for?
- Does an existing workflow agent already fit?
- Which skills, tools, project agents, and outputs are needed?
- What is missing?
- Where should HITL happen?
- Is the workflow local-only, cloud-allowed, or blocked?

The discovery orchestrator should usually produce a proposal before execution. It should not silently improvise a new legal workflow and finalize client-facing output.

If no permanent project agent fits a proposed work unit, the discovery orchestrator may propose a dynamic agent spec. A dynamic agent is an ephemeral role created from validated JSON for one run. It can perform specialist analysis, but it does not own finalization, HITL, durable state, or artifact writing. Once it has been run and accepted, it can be promoted into a permanent `.pi/agents/*.md` file.

## Decision Rule

Use this order:

1. If a specific workflow agent matches, use it.
2. If a specific workflow almost matches, let the discovery orchestrator propose adaptations.
3. If no workflow matches, let the discovery orchestrator propose an ad hoc workflow.
4. If the proposal has legal significance, client-confidential inputs, missing tools, or uncertain policy, require human approval before execution.

## Why Separate Them

Specific workflow agents are safer and faster because their contracts are known.

The discovery orchestrator is more flexible, but it must be more cautious. Its first product is an execution proposal, not a final answer.

This gives us both:

- repeatable workflow agents for productized legal workflows
- a real orchestrator for unusual document sets and non-typical requests
- a path to spawn one-run specialist agents without turning JSON into an uncontrolled workflow engine
