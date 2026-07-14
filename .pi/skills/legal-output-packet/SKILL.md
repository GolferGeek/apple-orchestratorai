---
name: legal-output-packet
description: Render and validate final legal workflow outputs, including markdown report, structured outputs, artifact instructions, display envelope, and next-workflow recommendations.
---

# Legal Output Packet

Use this skill only after required human review has completed.

## Required Outputs

- `response` markdown
- document onboarding report artifact instructions
- `documentsMetadata`
- `routingDecision`
- `specialistOutputs`
- `synthesis`
- human review decision
- output validation result

## Report Structure

1. Executive summary.
2. Documents reviewed.
3. Client and matter context.
4. Document classification.
5. Parties and key dates.
6. Specialist findings.
7. Risk matrix.
8. Recommended actions.
9. Suggested next workflows.
10. Human review decision ledger. Each discrete review item must retain its issue, proposed position or decision question, supporting citations, why it matters, reviewer decision or edit, and recorded disposition.

## Validation

Before completion, verify:

- required fields exist
- report renders as markdown
- legal findings have citations or review flags
- HITL is complete
- every material HITL segment is present in the report with its evidence and disposition
- output obeys local-only policy
- artifact instructions are complete
