---
name: legal-document-intake
description: Ingest legal documents from approved local files or resolved matter documents, extract text, preserve anchors, and produce stable document references.
---

# Legal Document Intake

Use this skill after source context is resolved.

## Inputs

- selected source documents
- local file references
- uploads
- base directory and approved roots
- client and matter context

## Required Behavior

1. Validate local paths against explicit user selections or approved roots.
2. Normalize files into stable document references.
3. Extract text and anchors.
4. Preserve tracked changes when possible.
5. Use OCR for scanned documents when OCR tooling is available.
6. Produce warnings for unsupported or unreadable files.

## Output Shape

```json
{
  "localFiles": [
    {
      "id": "string",
      "displayName": "string",
      "path": "string",
      "sourceUri": "string|null",
      "clientId": "string|null",
      "matterId": "string|null",
      "mimeType": "string|null",
      "sizeBytes": 0,
      "sha256": "string|null"
    }
  ],
  "documentsText": [
    {
      "documentId": "string",
      "displayName": "string",
      "text": "markdown",
      "anchors": [],
      "extractionMethod": "native-pdf|ocr|docx|text|structured|unknown"
    }
  ],
  "warnings": [],
  "sourceRefs": []
}
```

## Guardrails

- Reject path traversal.
- Do not send client-confidential content to cloud routes in local-only workflows.
- Keep extracted content tied to source references.
