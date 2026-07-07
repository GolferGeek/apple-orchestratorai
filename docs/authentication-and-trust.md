# Authentication and Trust

Apple Orchestrator AI Local should be local-only by default, but it still needs a clear trust model.

## Local Boundary

The Mac is the trusted execution node:

- Hermes runs locally.
- Ollama runs locally.
- Workflow JSON files live locally.
- Matter workspaces live locally.
- The observability database lives locally.
- iPhone and iPad are controllers.

## User Identity

For the first build, identity can be local-device identity:

- one local owner profile
- optional local display name
- optional device pairing records for iPhone/iPad controllers

Do not introduce SaaS accounts for the local product.

## Profile Trust

Hermes profiles are trust and memory boundaries.

The app should ship versioned profile manifests, but should not commit live profile memory or state. Runtime profile data may contain personal preferences, legal-workflow assumptions, coding plans, drafts, or research history.

Committed product profile:

- `legal-dev`

Private local profiles, gitignored under `config/hermes-profiles.local/`:

- `personal`
- `coder`
- `book-writer`
- `post-writer`
- `ai-scout`
- `golfer`
- `company-growth`

The app may route requests automatically, but ambiguous routing should ask for confirmation. Cross-profile memory promotion should be explicit.

## Device Pairing

iPhone/iPad controllers need a pairing mechanism with the Mac.

Initial intention:

- Mac shows pairing code or QR code.
- Controller app connects to Mac on local network.
- Mac approves pairing.
- App stores a local device token/key.
- Mac can revoke paired devices.

## Action Authorization

Controller actions should be scoped:

- view run status
- view outputs
- create capture
- start approved workflows
- approve/reject human tasks
- pause/resume/cancel runs

Dangerous actions, such as deleting workspaces or changing connector credentials, should require Mac-side confirmation in v1.

## MCP Resource Trust

MCP resources are external access paths. Hermes can request them, but the user/app grants them.

Record:

- resource id
- connector type
- scope
- credential reference, not raw credential when avoidable
- approving user/device
- first used timestamp
- last used timestamp
- runs that used it

## Workflow Pack Trust

Workflow packs should eventually be signed or at least source-labeled.

For v1:

- local/manual install is acceptable
- show source folder
- show pack manifest
- warn on unknown packs
- keep workflow JSON inspectable

Future:

- signed workflow packs
- publisher metadata
- compatibility declarations
- permission/resource declarations before install
