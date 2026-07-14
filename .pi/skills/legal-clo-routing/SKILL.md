---
name: legal-clo-routing
description: Route a legal document packet to selected specialist lanes with rationale, alternatives, confidence, and human-review flags.
---

# Legal CLO Routing

Use this skill after metadata extraction.

## Available Lanes

- contract
- compliance
- ip
- privacy
- employment
- corporate
- litigation
- real-estate

## Required Behavior

1. Select every specialist lane needed.
2. Broaden coverage when confidence is low.
3. Explain the rationale for each selected lane.
4. Preserve alternatives.
5. Flag routing issues for human review.

## Output Shape

```json
{
  "routingDecision": {
    "selectedLanes": [],
    "laneRationales": {},
    "alternatives": [],
    "documentTypeMap": {},
    "confidence": 0,
    "humanReviewFlags": [],
    "sourceRefs": []
  }
}
```
