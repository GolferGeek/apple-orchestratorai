# Local Runtime State

The local database is for observability, state, outputs, and audit. It is not the source of workflow structure.

V1 should use Apple-native persistence, not MySQL or Supabase. The Mac Studio execution authority owns runtime database writes. iPhone and iPad controllers submit work, approvals, questions, and steering through app-controlled surfaces rather than writing runtime state as peers.

It should store:

- runs
- run steps
- run events
- human tasks
- outputs
- artifacts
- matter workspaces
- MCP resources
- resource bindings
- connector configs
- access policies
- audit events

The Apple UI reads this state to show what is running, completed, failed, blocked, or waiting for human input.

## Output Flexibility

Outputs should be flexible. The runtime state model should support:

- renderable inline outputs
- updated outputs
- generated files
- artifact bundles
- document references
- exported files
- output versions

Hermes skills may own output generation directly. The app should record enough metadata to display, open, compare, export, and audit the output without requiring every output to use the same storage format.

Most workflows should produce a final output package. The package may contain one file, many files, structured records, or links to generated artifacts. The observability database should track both the package and each item in it.

The database should also track intermediate output packages when they are reviewable, especially outputs tied to human tasks. A human task should be able to point to the exact output package being approved or changed.

## Segmented Human Tasks

Some human tasks require decisions on multiple segments inside the same review package. The runtime state should support:

- top-level human task status
- review package reference
- review segments
- per-segment decision
- per-segment modification text
- per-segment audit events
- final aggregate decision

This supports workflows like contract review, discovery review, memo section approval, timeline approval, and fact extraction correction.
