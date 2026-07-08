# Legal Data And File Model

This captures the data model we should carry forward from OrchestratorAI Local into Apple Orchestrator AI.

## Existing Local Pattern

OrchestratorAI Local already has the right product shape for document-backed legal workflows:

```text
Clients -> Matters -> Matter Documents -> Launch Workflow
```

The existing frontend uses a three-pane picker:

- Clients
- Matters
- Documents

The user can also choose "Upload files instead." For Apple Orchestrator AI, that should become:

- choose from known client/matter documents
- upload files
- browse or select local files as Hermes sees them

The relevant existing files in `orchestratorai-local` are listed below as source references. They describe the existing product shape and logical schema; they do not imply that Apple Orchestrator AI should use Supabase/Postgres.

```text
apps/web/src/legal/components/DocumentOnboardingSubstratePickerModal.vue
apps/web/src/legal/DocumentOnboardingPage.vue
apps/web/src/legal/legalJobsService.ts
apps/api/src/legal/substrate/legal-substrate.service.ts
apps/api/src/legal/substrate/legal-substrate.types.ts
apps/api/src/legal/workflows/document-onboarding/document-onboarding-substrate.service.ts
apps/api/supabase/migrations/20260608134000_legal_portfolio_foundation.sql
apps/api/supabase/migrations/20260609170000_legal_demo_substrate_schema.sql
supabase/migrations/00000000000000_local_baseline.sql
```

## What The Frontend Needs To Present

Document Onboarding should not start with a blank file upload as the primary UX. It should start with legal context.

The primary picker should show:

1. Client search/list.
2. Matter search/list, optionally filtered by selected client.
3. Document list for the selected matter, with multi-select.
4. Launch button once at least one document is selected.
5. Alternate actions:
   - Upload files.
   - Browse local files.
   - Attach external source through Hermes/MCP.

This mirrors the current local app and maps naturally to a Mac app. The workflow remains voice-first, but when the user says "run document onboarding for Acme," the app can open this picker or ask Hermes to resolve the client/matter.

## Recommended Apple Local Database Entities

Use Apple's local persistence stack for legal metadata, workflow state, and document pointers. In practice this likely means SwiftData/Core Data backed by CloudKit/iCloud where appropriate, with Hermes accessing the data through an app-owned service or skill contract. Do not store every client file blob in the database by default.

Minimum entities:

### `LegalClient`

Stores client identity and browse metadata.

Fields:

- `id`
- `workspaceId`
- `name`
- `client_type`
- `industry`
- `primary_contact`
- `description`
- `status`
- `metadata`
- `created_by`
- `created_at`
- `updated_at`

- `slug`
- unique `(workspaceId, slug)`

The current local system stores slug in `metadata->>'slug'` in some paths. For Apple Orchestrator AI, make it a first-class property.

### `LegalMatter`

Stores matter identity and high-level legal context.

Fields to keep:

- `id`
- `workspaceId`
- `slug`
- `client_id`
- `created_by`
- `name`
- `client_name`
- `matter_type`
- `jurisdiction`
- `opposing_parties`
- `assigned_user_ids`
- `status`
- `description`
- `metadata`
- `opened_at`
- `closed_at`
- `updated_at`

Recommended indexes:

- unique `(workspaceId, slug)`
- `(workspaceId, status)`
- `(clientId)` where not null

### `LegalMatterDocument`

Stores document pointers and extracted/browse metadata.

Fields to keep:

- `id`
- `matterId`
- `workspaceId`
- `slug`
- `storage_path`
- `original_name`
- `document_class`
- `document_date`
- `parties`
- `key_terms`
- `summary`
- `metadata`
- `facts_processed`
- `docs_processed`
- `uploaded_at`
- `uploaded_by`

Recommended additions for Apple/Hermes:

- `source_kind`: `local_file`, `upload`, `icloud_file`, `external_mcp`, `app_storage`
- `source_uri`: stable URI or local path reference
- `file_bookmark`: security-scoped bookmark or app-managed access token when Swift needs it
- `content_hash`: dedupe and audit
- `mime_type`
- `size_bytes`
- `last_seen_at`

Recommended indexes:

- unique `(workspaceId, matterId, slug)`
- `(matterId)`
- `(workspaceId, source_kind)`
- `(content_hash)` where not null

### `WorkflowRun`

Keep workflow run state in the Apple local database.

The existing local app records:

- `input`
- `result`
- `review_decision`
- `document_paths`
- `document_count`
- status values such as `queued`, `processing`, `awaiting_review`, `completed`, `failed`

For Apple Orchestrator AI, the run record should also snapshot:

- `workflow_id`
- `workflow_version`
- `client_id`
- `matter_id`
- selected `document_ids`
- selected `storage_paths`
- selected `source_uris`
- Hermes run ID
- model route used
- human review status

## File Storage Recommendation

Move client files outside the app bundle and outside the database by default.

Recommended layers:

```text
Apple local database: clients, matters, document metadata, workflow runs, review decisions
File system: actual client/matter documents and generated artifacts
Hermes skills: resolve files, extract text, enforce allowed roots, call MCP/database adapters
Apple app: present picker, show status, show outputs, request user approval
```

The Apple local database should store stable pointers to files, not the whole client universe.

Good file roots:

- user-selected local folder
- app-managed local documents folder
- iCloud Drive folder for portable input files
- external client/matter root mounted locally
- MCP-backed external source resolved by Hermes

For the Mac app, local filesystem access should be explicit. The app can store security-scoped bookmarks for selected directories/files. Hermes should still enforce an allowed-root policy before reading paths.

## Hermes Skill Boundaries

The old "substrate service" becomes a set of Hermes skills.

Shared skills:

- `shared.local-file-resolve-documents.v0`
- `shared.file-ingest.v0`
- `shared.text-extract.v0`
- `shared.ocr-if-needed.v0`
- `shared.docx-tracked-changes-extract.v0`

Legal shared skills:

- `legal.shared.list-clients.v0`
- `legal.shared.list-matters.v0`
- `legal.shared.list-matter-documents.v0`
- `legal.shared.apple-store-resolve-client-matter.v0`
- `legal.shared.extract-document-metadata.v0`
- `legal.shared.clo-route-specialists.v0`
- specialist review skills

Workflow skills:

- `workflow.launch-from-legal-source-selection.v0`
- `workflow.persist-run-observability.v0`
- `workflow.request-human-review.v0`
- `workflow.export-document.v0`

Workflow-specific legal skills:

- `legal.workflow.document-onboarding.v0`
- `legal.workflow.document-onboarding.synthesize-findings.v0`
- `legal.workflow.document-onboarding.recommend-next-workflow.v0`

## Launch Contract

The Apple/Hermes launch contract should preserve the existing useful shape:

```json
{
  "workflowId": "document-onboarding",
  "clientId": "client uuid or external id",
  "clientSlug": "acme-corp",
  "matterId": "matter uuid or external id",
  "matterSlug": "acme-commercial-contract-review",
  "documentIds": ["document uuid or external id"],
  "documentSlugs": ["acme-cloud-services-msa"],
  "filePaths": ["/safe/local/path/acme-cloud-services-msa.pdf"],
  "sourceUris": ["file:///...", "mcp://...", "icloud://..."],
  "instructions": "optional reviewer lens"
}
```

The workflow should not care whether the documents came from upload, iCloud, a copied client folder, or a SQL-backed document table. It should receive a resolved set of document references and legal context.

## Decision

Recreate the OrchestratorAI Local picker and data model, but make files external by default.

Store in the Apple local database:

- client records
- matter records
- document metadata and file pointers
- workflow run state
- human review decisions
- extracted metadata and output summaries

Keep outside the Apple local database by default:

- original client files
- bulk file trees
- large generated artifacts unless the user explicitly imports them

This gives the Mac app the rich browse-and-launch UX from OrchestratorAI Local while preserving the Apple/Hermes idea: files and external databases are accessed through skills, not hardcoded app planes.
