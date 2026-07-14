---
name: workflow-coordinator-duties
description: Shared coordinator duties for Apple Orchestrator AI workflow agents, including tool ownership, event emission, run entries, HITL, artifacts, model policy, and bounded delegation.
---

# Workflow Coordinator Duties

Use this skill when a workflow agent needs to perform coordinator duties.

A workflow agent may own a specific domain workflow while using this shared coordinator-duty contract. The workflow agent remains responsible for its own phases, work units, teams, outputs, and workflow-specific rules.

## Duties

1. Accept and validate the workflow launch payload.
2. Confirm model policy and sovereignty constraints before delegation.
3. Keep the frontend out of data-access and document-processing work.
4. Own app workflow tools for source resolution, document resolution, text extraction, HITL, artifact writing, and structured output.
5. Delegate bounded role work to named project agents or workflow-specific sub-agents.
6. Persist important intermediate outputs as run entries.
7. Emit normalized workflow, graph, subgraph, work-unit, team, role, HITL, output, and failure events.
8. Maintain work-team and role progress.
9. Pause at required human review.
10. Resume only from durable run state and valid reviewer decisions.
11. Refuse finalization when required outputs, citations, approvals, or output validations are missing.

## Bounded Delegation

Each delegated agent call should have:

- explicit `agent`
- compact task prompt
- model tier or explicit model policy reason
- timeout
- required output packet
- run entry name
- event updates for role/team progress

Do not use child agents for app-owned side effects unless the child agent is explicitly allowed to call the relevant tool.

## Non-Chatty Rule

Do not produce text-only continuation messages between deterministic tool steps. If a tool result gives enough information for the next required tool call, call the next tool immediately.

Acceptable stops are:

- request human review
- emit workflow completion
- emit workflow failure
- return a structured output
- ask a required clarification when no safe default exists

## Event Rule

Every event tool call must include the exact event `type`. Include correlation fields whenever known:

- `runId`
- `workflowId`
- `graphId`
- `subgraphId`
- `workUnitId`
- `teamId`
- `roleId`
- `agentId`
- `skillId`
- `summary`

## Output Rule

Final workflow output must be produced only after:

- all required work teams are complete
- required HITL is complete
- final artifact instructions are written or ready
- final output validation passes or explicitly records non-blocking warnings
