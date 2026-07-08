# Legal Document Onboarding

This is the first workflow JSON candidate for Apple Orchestrator AI.

The source definition is:

```text
workflows/legal/document-onboarding.workflow.json
```

The current golden-path execution plan is:

```text
workflows/legal/document-onboarding.execution-plan.json
```

The intent is to model document onboarding as a workflow definition, not as code. Hermes should execute the workflow by resolving the requested skills, persisting run observability, and returning schema-shaped outputs that the Mac app can display.

## Launch Payload

The reference launch payload is:

```text
test-fixtures/legal/document-onboarding/acme-renewal/launch-payload.json
```

The Mac app sends the same logical shape to Hermes when document onboarding starts. Hermes should treat this as the workflow source of truth and resolve all client, matter, and document references through skills or MCPs.

## Input Model

Document onboarding needs both document bytes and legal context.

The Apple/Hermes version should support three input paths:

- **Local file paths:** the lawyer or student has a safe local copy of client/matter documents on the Mac, and Hermes receives file paths plus client/matter identifiers.
- **Apple-store-backed matter documents:** Hermes resolves a client, matter, and document list from the app's Apple local database through an app-owned service or skill.
- **Manual upload:** the user supplies files outside the configured source.

The important fields are:

- `clientId` or `clientSlug`
- `matterId` or `matterSlug`
- `filePaths`
- `baseDirectory`
- optional `documentSlugs` when the documents are selected from a configured matter-document table

This keeps the old "substrate" idea but makes it more Apple/Hermes friendly. Hermes does not need a hardcoded file plane. It needs skills that can resolve local files and Apple-store matter context safely.

## Skill Split

Yes, the skills should be separated into four practical groups.

### Workflow Skills

Workflow skills operate the workflow itself. They should not know legal doctrine.

Examples:

- `workflow.load-definition.v0`
- `workflow.validate-definition.v0`
- `workflow.run-structured-graph.v0`
- `workflow.request-human-review.v0`
- `workflow.persist-run-observability.v0`
- `workflow.render-output-packet.v0`

These are the skills that let Hermes understand the JSON, run graphs and subgraphs, pause for human review, and write observable run state.

### Shared Skills

Shared skills are reusable across legal, accounting, writing, scouting, and other domains.

Examples:

- `shared.file-ingest.v0`
- `shared.local-file-resolve-documents.v0`
- `shared.text-extract.v0`
- `shared.ocr-if-needed.v0`
- `shared.detect-document-boundaries.v0`
- `shared.summarize.v0`
- `shared.schema-validate.v0`
- `shared.write-artifacts.v0`

These should stay domain-neutral. A PDF text extractor should not know what a complaint, contract, or engagement letter is.

The important non-legal shared skills for this workflow are:

- `shared.local-file-resolve-documents.v0`: takes file paths, normalizes them, verifies allowed local access, and returns stable document references.

### Legal Shared Skills

Legal shared skills are reusable across legal workflows. They understand legal-domain concepts such as clients, matters, documents, parties, dates, obligations, privilege, routing, and specialist review lanes, but they should not be tied to one workflow's final output.

Examples:

- `legal.shared.list-clients.v0`
- `legal.shared.list-matters.v0`
- `legal.shared.list-matter-documents.v0`
- `legal.shared.apple-store-resolve-client-matter.v0`
- `legal.shared.extract-document-metadata.v0`
- `legal.shared.classify-document-type.v0`
- `legal.shared.detect-sections.v0`
- `legal.shared.detect-signatures.v0`
- `legal.shared.extract-dates.v0`
- `legal.shared.extract-parties.v0`
- `legal.shared.detect-privilege-and-confidentiality.v0`
- `legal.shared.clo-route-specialists.v0`
- `legal.shared.specialist.contract-review.v0`
- `legal.shared.specialist.compliance-review.v0`
- `legal.shared.specialist.ip-review.v0`
- `legal.shared.specialist.privacy-review.v0`
- `legal.shared.specialist.employment-review.v0`
- `legal.shared.specialist.corporate-review.v0`
- `legal.shared.specialist.litigation-review.v0`
- `legal.shared.specialist.real-estate-review.v0`

Legal shared skills should produce confidence values, source references, and human-review flags. They should not silently convert uncertain interpretations into final legal conclusions.

### Workflow-Specific Legal Skills

Workflow-specific legal skills know the purpose and final work product of a specific workflow. They may compose legal shared skills, but should stay thin.

Examples:

- `legal.workflow.document-onboarding.v0`
- `legal.workflow.document-onboarding.synthesize-findings.v0`
- `legal.workflow.document-onboarding.recommend-next-workflow.v0`

This split matters because contract review, privilege detection, party extraction, matter lookup, and specialist routing should be usable by other workflows later.

## Workflow Shape

The current JSON uses this hierarchy:

```text
workflow
  graph
    subgraph
      workUnit
```

For document onboarding, the graphs are:

- `document-intake`: resolve files, extract readable text, OCR if needed.
- `legal-understanding`: classify documents, infer matter context, extract parties, dates, sensitivity flags, deadlines, and obligations.
- `human-review-and-output`: render a review packet, collect approval or corrections, write final artifacts, and recommend downstream workflows.

## Human Review

The human-in-the-loop checkpoint is explicit:

```text
request-human-approval
```

The user can approve, approve with corrections, request changes, or archive. Editable fields include document type, matter context, parties, dates, deadlines, obligations, and routing.

This matters because document onboarding is where the system first touches legal meaning. The workflow can prepare the packet, but the human decides whether it is right enough to become part of the matter record.

## Open Design Questions

- Should the workflow JSON include UI hints, or should Hermes return separate display contracts for each run state?
- Should legal skills be bundled with the app, with Hermes, or installed as a legal skill pack?
- Should matter context be read from Apple-local storage, an MCP-backed source, or both?
- Should document onboarding automatically recommend next workflows, or only list possible next workflows for human selection?
- Should the final metadata schema be generic across legal workflows, or specific to document onboarding?

My current recommendation: keep the workflow JSON execution-focused, and have Hermes return display-shaped JSON separately for the Mac app. That keeps the workflow portable and avoids turning every workflow into a custom UI contract.
