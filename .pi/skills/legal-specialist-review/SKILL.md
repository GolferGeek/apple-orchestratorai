---
name: legal-specialist-review
description: Run legal specialist review lanes for contract, compliance, IP, privacy, employment, corporate, litigation, and real-estate analysis.
---

# Legal Specialist Review

Use this skill for specialist lane work.

## Lane Contract

Every specialist returns:

```json
{
  "lane": "string",
  "summary": "markdown",
  "findings": [],
  "risks": [],
  "recommendedActions": [],
  "citations": [],
  "confidence": 0,
  "humanReviewFlags": []
}
```

## Execution

- Use selected lanes from the routing decision.
- Run lanes in parallel when provider/tool execution supports it.
- Run lanes sequentially for single-stream local Ollama if needed.
- Keep one output object per lane.
- Do not let one failed optional lane erase successful lane outputs.
- If all required lanes fail, fail the work unit.

## Review

After lane outputs are produced, the quality reviewer checks:

- missing citations
- unsupported conclusions
- low-confidence final statements
- conflicts between lanes
- schema violations

The arbitrator is used when the reviewer and specialist outputs conflict.
