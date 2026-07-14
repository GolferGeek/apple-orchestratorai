# Workflow Agent Architecture

Apple Orchestrator AI workflows are executable agents, not JSON execution plans.

## Core Rule

Each known workflow should have a specific workflow agent. The workflow agent owns:

- phases
- graphs and subgraphs
- work units
- work teams
- agent roles
- delegated project agents or sub-agents
- workflow-specific skills
- shared skills
- HITL checkpoints
- output contracts
- pause/resume behavior
- workflow events and run entries

JSON files can describe, catalog, test, or display a workflow, but they do not run the workflow.

## Coordinator Duties

Coordinator duties are a reusable contract that a workflow agent can reference. They do not replace the workflow agent.

Use `.pi/skills/workflow-coordinator-duties/SKILL.md` when a workflow agent needs the shared orchestration behavior:

- launch validation
- model policy enforcement
- app/tool boundary ownership
- event emission
- durable run entries
- team and role progress
- HITL pause/resume
- artifact and structured-output finalization
- bounded child-agent delegation

The workflow agent still owns its domain shape. For example, `legal-document-onboarding-coordinator` is the Document Onboarding workflow agent, and it references coordinator duties while defining its own phases, teams, legal agents, HITL packet, and outputs.

## Workflow-Specific Versus Shared

Use workflow-local components when behavior is specific to one workflow:

- workflow-specific phase skill
- workflow-specific sub-agent
- workflow-specific output packet
- workflow-specific HITL payload

Use shared components when behavior is reusable:

- shared legal specialist agents
- shared legal skills
- shared quality reviewer
- shared arbitrator
- shared source/document tools
- shared workflow observability tools

The goal is not to centralize everything. The goal is to keep reusable capabilities reusable while letting each workflow agent express its own shape clearly.

## Phase Contracts

A workflow phase should be bounded:

- required inputs
- allowed tools
- delegated agent or sub-agent
- model tier
- timeout
- output packet
- run entry name
- emitted event names
- completion condition
- failure or HITL condition

This keeps the workflow agent agentic without allowing open-ended conversation between deterministic steps.

## Document Onboarding

`legal-document-onboarding-coordinator` is the Document Onboarding workflow agent.

It references `workflow-coordinator-duties` for shared orchestration behavior. It may call shared agents such as `legal-quality-reviewer`, `legal-arbitrator`, and legal specialist agents. If a phase becomes too specific or too complex, it should become a document-onboarding phase skill or sub-agent rather than being pushed into a generic shared runner.
