---
name: workflow-builder
description: Design, assess, and revise Apple Orchestrator workflow-agent Markdown with complete phases, work units, teams, roles, agent assignments, skills, tools, outputs, events, model policy, and human review.
disable-model-invocation: true
---

# Workflow Builder

Use this skill to create or revise an Apple Orchestrator workflow agent. A workflow is not a diagram, a JSON file, or a list of generic labels. It is an editable operating contract that a user must be able to inspect, understand, and maintain in the Workflow Agent Builder.

The workflow-agent Markdown is the source of truth for workflow structure and workflow-specific behavior. Pi provides execution mechanics; the workflow definition supplies the intent, hierarchy, bounded responsibilities, and observable completion rules.

## Required Hierarchy

Build only the levels the work genuinely needs, but account for each level explicitly:

1. **Workflow agent**: purpose, scope, ownership, model/data policy, start and terminal conditions.
2. **Phase**: a meaningful business outcome, entry criteria, completion boundary, and handoff to the next phase.
3. **Subphase**: an optional focused execution path or graph within a phase. Explain why it exists and how it completes.
4. **Work unit**: one durable unit of work with required inputs, expected packet or artifact, completion test, model route, and observable events.
5. **Work team**: the collaborating roles, their sequence or fan-out behavior, team packet, quality/arbitration rule, and stop condition.
6. **Role**: the bounded responsibility inside one team, its assigned reusable agent, evidence standard, escalation rule, expected role packet, and prohibition against performing neighboring roles.
7. **Skill**: the focused reusable procedure a role invokes. Record why it is needed in this invocation and what it contributes; do not write “skill included” or similar filler.
8. **Tool**: a permitted side-effect or retrieval capability. Record what it does, why this role may use it, expected result, and authority boundary.
9. **Output**: a durable handoff. Record producer, consumers, required content, validation rule, and what cannot continue until it exists.

## Description Standard

Every visible node description must answer enough of these questions for a non-technical workflow owner to understand it:

- What business or legal outcome does this node produce?
- What facts, packets, or approvals does it need first?
- What does it do, and what is explicitly outside its authority?
- What does it hand to the next node or to a human?
- How does the system know it is complete, blocked, or failed?

Avoid generic descriptions such as “sequential workflow phase,” “reusable skill used by X,” “permitted tool,” or “durable output.” Replace them with context-specific language tied to the enclosing role, team, work unit, or phase.

## Invocation Contracts

Define editable Markdown invocation contracts in the workflow agent file:

- a workflow operating contract for evidence, sovereignty, uncertainty, and authority;
- a shared role contract for run context, upstream packets, response shape, and escalation;
- a role-specific contract for every distinct responsibility, with any justified shared contract for repeated specialist lanes.

The runtime may interpolate live run context and prior role outputs. It must not hide material workflow policy in code. When a role uses an agent, the workflow Markdown owns the role-to-agent assignment and the role-specific brief; the reusable agent file owns durable domain expertise.

## Agents, Skills, And Tools

- Use a reusable agent when durable expertise is shared across roles or workflows.
- Use a workflow-specific role contract when the same agent has a different responsibility in this workflow.
- Load the full selected skill only for the role that needs it. Do not place every skill body in every agent prompt.
- Treat a tool as an explicit capability, not an instruction. The definition should make its side effects, data boundary, and event behavior visible.
- Do not create an agent, skill, or tool merely to make the tree look complete. Every item must have a real operating purpose.

## Models And Data Policy

For every workflow and work unit, record the allowed model route and the reason for any stronger model. Respect local-only or sovereign policy as an execution requirement, not a marketing label. Model selection is separate from role identity: a role names responsibility; an agent provides expertise; the model is an execution choice.

## Human Review And Observability

Add human review when a decision requires authority, legal judgment, acceptance of uncertainty, or approval of a consequential change. A review packet must contain discrete reviewable segments, evidence, available decisions, and downstream consequences.

Define events at the workflow, phase/subphase, work-unit, team, role, tool, human-review, and output levels where useful. Events must let a user see what is running, what completed, what failed, what is waiting for a person, and what model executed the work.

## Builder Output

When asked to design or revise a workflow, return:

1. Assumptions and questions that materially affect the structure.
2. A proposed hierarchy with specific descriptions and boundaries for every node.
3. Role-to-agent assignments, selected skills, allowed tools, model routes, outputs, and events.
4. Invocation-contract additions or revisions.
5. A completeness review listing missing definitions, generic wording, hidden behavior, duplicated policy, or unsafe authority gaps.
6. A concise proposed Markdown change set for human approval.

Do not silently alter a production workflow. The user reviews and accepts changes through the Workflow Agent Builder.
