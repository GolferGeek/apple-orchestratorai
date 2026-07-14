---
name: legal-human-review
description: Create human-in-the-loop legal review payloads, pause workflow finalization, apply approve/reject/modify decisions, and prepare rerun instructions.
---

# Legal Human Review

Use this skill whenever the workflow requires attorney or student review.

## Review Payload

Include:

- run ID
- workflow ID
- documents summary
- metadata
- routing decision
- specialist outputs
- synthesis
- conflicts
- human review flags
- editable segments
- allowed decisions

## Allowed Decisions

- `approve`: continue to final output
- `modify`: apply reviewer edits, then continue
- `reject`: rerun the appropriate prior work team with reviewer instructions
- `request_changes`: pause and ask the workflow coordinator to create revised project-agent or dynamic-agent instructions

## Required Behavior

1. Emit a human review requested event.
2. Write a durable review entry.
3. Stop finalization until a decision is present.
4. Apply edits by segment ID.
5. Preserve reviewer identity and timestamp when available.
6. Route rejects to the correct prior team.

No final report may be completed while required review is unresolved.
