---
name: legal-metadata-extraction
description: Extract legal metadata from document text, including document type, sections, signatures, dates, parties, deadlines, obligations, sensitivity, confidence, and source references.
---

# Legal Metadata Extraction

Use this skill to prepare document understanding before routing.

## Extract

- document type and alternatives
- sections and clauses
- signature blocks
- dates and deadlines
- parties and roles
- obligations and notice requirements
- confidentiality, privilege, and sensitivity signals
- confidence and warning details

## Output Shape

```json
{
  "documentsMetadata": [
    {
      "documentId": "string",
      "documentType": {
        "type": "string",
        "confidence": 0,
        "alternatives": [],
        "reasoning": "markdown"
      },
      "sections": {},
      "signatures": {},
      "dates": {},
      "parties": {},
      "deadlines": [],
      "obligations": [],
      "sensitivityFlags": [],
      "confidence": {
        "overall": 0,
        "breakdown": {},
        "factors": {}
      },
      "warnings": [],
      "sourceRefs": []
    }
  ]
}
```

## Guardrails

- Low confidence must be visible.
- Missing metadata should become warnings, not invented facts.
- Prefer source-cited findings.
