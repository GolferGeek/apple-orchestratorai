---
name: legal-document-source
description: Resolve legal clients, matters, document source options, selected documents, and connector requirements for legal workflows. Use before document intake or whenever the UI needs legal source picker data.
---

# Legal Document Source

Use this skill to resolve legal source context without putting legal data access in the Swift frontend.

## Inputs

- workflow launch payload
- optional `clientId` or `clientSlug`
- optional `matterId` or `matterSlug`
- optional `documentIds` or `documentSlugs`
- optional local file paths or source URIs
- optional source hint such as `apple-local`, `fixture`, `sql-server-mcp`, or `document-management-mcp`

## Required Behavior

1. Prefer explicit IDs from the launch payload.
2. Resolve clients, matters, and documents through approved tools.
3. If picker data is requested, return display-safe summaries only.
4. If a connector is missing, return a connector requirement object.
5. Never infer client identity from document text alone.
6. If identifiers conflict, request human review.

## Output Shape

```json
{
  "client": {
    "id": "string",
    "slug": "string",
    "name": "string",
    "clientType": "string|null",
    "industry": "string|null"
  },
  "matter": {
    "id": "string",
    "slug": "string",
    "name": "string",
    "matterType": "string|null",
    "status": "string|null",
    "jurisdiction": "string|null"
  },
  "documentOptions": [],
  "selectedDocuments": [],
  "connectorRequirements": [],
  "warnings": [],
  "sourceRefs": []
}
```

## Guardrails

- The Apple app asks for source options; it does not query external legal systems directly.
- Credentials remain in app or connector configuration.
- Return logical IDs and display labels for UI lists.
