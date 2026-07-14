---
name: legal-synthesis
description: Synthesize legal metadata, routing decisions, and specialist outputs into cross-document findings, risk matrix, recommendations, conflicts, and attorney review questions.
---

# Legal Synthesis

Use this skill after specialist review.

## Required Behavior

1. Combine specialist findings into a coherent document onboarding view.
2. Preserve specialist disagreements.
3. Compare multiple documents together.
4. Build a risk matrix.
5. Identify attorney review questions.
6. Recommend next actions and downstream workflows.
7. Preserve citations and confidence.

## Output Shape

```json
{
  "synthesis": {
    "executiveSummary": "markdown",
    "riskMatrix": [],
    "crossDocumentFindings": [],
    "recommendedActions": [],
    "conflicts": [],
    "humanReviewFlags": [],
    "confidence": 0
  }
}
```

## Guardrails

- Synthesis is not final legal advice until HITL is complete.
- Do not hide conflicts.
- Do not drop source references.
