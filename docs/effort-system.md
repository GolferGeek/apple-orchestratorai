# App Effort System

Every app gets an `efforts/` directory. This is the file-based work queue that Hermes, Codex, and the Apple app can all understand.

## App Folder Shape

```text
apps/
  <app-id>/
    efforts/
      inbox/
      current/
      future/
      archive/
```

Directory meanings:

- `inbox/`: raw intention files. These are proposals, not active efforts.
- `current/`: accepted active efforts.
- `future/`: accepted or useful efforts that are not active now.
- `archive/`: completed, abandoned, superseded, or historical efforts.

This repository starts with one registered app:

```text
apps/
  apple-orchestratorai/
    efforts/
      inbox/
      current/
      future/
      archive/
```

Known apps are listed in `config/apps.json`. External apps, such as Orchestrator AI Enterprise or Orchestrator AI Local, should be registered there with their own app ids and effort roots rather than copied into this repository.

## Intake Rule

The inbox item is the user's intention. It should not become an active effort automatically.

The agent intake pass decides:

- If clear enough, accept it, create a folder under `current/`, create the plan, and start the run.
- If important information is missing, write blocking questions and do not create the effort yet.
- If useful but not current, create or move the accepted effort under `future/`.

## Intention File

Inbox intentions should be human-readable Markdown:

```text
efforts/
  inbox/
    2026-07-07-add-profile-contract.md
```

The file should include enough context for intake:

```markdown
# Effort: Add Profile Contract Schema

## Goal
Create a JSON schema for Hermes profile manifests.

## Context
Use the profile decisions already captured in docs.

## Constraints
Keep runtime paths logical. Do not add API-key-only providers.

## Acceptance Criteria
- Schema exists.
- Example profiles validate.
- Docs explain the fields.
```

## Accepted Effort Folder

Every accepted effort uses the same folder template:

```text
current/
  add-profile-contract/
    effort.json
    intention.md
    plan.md
    shared-notes.md
    next-actions.md
    later.md
    questions.json
    run-log.jsonl
    result.md
    artifacts/
```

Required files:

- `effort.json`: structured metadata and lifecycle state.
- `intention.md`: accepted intention copied from the inbox item.
- `plan.md`: current plan.
- `shared-notes.md`: durable context shared by Hermes and Codex.
- `next-actions.md`: immediate agreed next steps.
- `later.md`: parked ideas and follow-ups.
- `questions.json`: blocking and nonblocking questions for the app to display.
- `run-log.jsonl`: append-only machine-readable event log.
- `result.md`: latest or final user-facing result summary.
- `artifacts/`: generated files, patches, reports, exports, or bundles.

The note files may be empty when the effort is created. Creating them every time gives agents and the app stable places to read and write.

## Effort Metadata

```json
{
  "schemaVersion": "0.1.0",
  "id": "add-profile-contract",
  "appId": "apple-orchestratorai",
  "profileId": "coder",
  "status": "current",
  "sourceIntention": "../../inbox/2026-07-07-add-profile-contract.md",
  "createdBy": "coder",
  "createdAt": "2026-07-07T00:00:00Z",
  "inferenceRoute": "codex-subscription",
  "turn": {
    "owner": "codex",
    "state": "ready",
    "reason": "Effort has been accepted and is ready for Codex planning.",
    "since": "2026-07-07T00:00:00Z",
    "questionIds": []
  }
}
```

## Turn Ownership

The authoritative handoff marker lives in `effort.json`, not prose notes.

Turn owners:

- `user`
- `hermes`
- `codex`
- `pi`
- `app`
- `external`

Turn states:

- `needs-input`
- `ready`
- `working`
- `blocked`
- `review`
- `done`

Examples:

```json
{
  "turn": {
    "owner": "user",
    "state": "needs-input",
    "reason": "Blocking question q1 needs an answer before effort creation.",
    "since": "2026-07-07T00:00:00Z",
    "questionIds": ["q1"]
  }
}
```

```json
{
  "turn": {
    "owner": "codex",
    "state": "review",
    "reason": "Codex has completed implementation and needs user or Hermes review.",
    "since": "2026-07-07T00:00:00Z",
    "questionIds": []
  }
}
```

`next-actions.md` should mirror the turn state in human language, but the app should read `effort.json` as the source of truth.

## Questions

If intake cannot safely accept an intention, the agent writes a question record that the app can show:

```json
{
  "schemaVersion": "0.1.0",
  "sourceIntention": "2026-07-07-add-profile-contract.md",
  "status": "needs-question",
  "questions": [
    {
      "id": "q1",
      "question": "Should profile schema validation allow unknown extension fields?",
      "blocking": true,
      "status": "open"
    }
  ]
}
```

When answered, the app writes the answer back into the same question record or an adjacent answer record. The agent can then run intake again.

## Shared Notes

`shared-notes.md` is the living coordination note for Hermes and Codex. It should capture what is being discussed and what both agents need to remember for this effort.

Use `next-actions.md` for immediate next steps. Use `later.md` for deferred ideas so they do not pollute the active plan.

## Scripts

Initialize a local app effort folder:

```bash
scripts/init-app-efforts.sh apple-orchestratorai
```

Validate registered app effort folders and accepted effort templates:

```bash
scripts/check-efforts.sh
```
