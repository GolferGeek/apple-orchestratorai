# Testing Strategy

Testing should protect the contracts and the first vertical slice.

## Contract Tests

Validate:

- workflow JSON examples
- workflow pack manifests
- Hermes display responses
- Hermes events
- Hermes actions
- output metadata
- resource bindings

## Mac App Tests

Test:

- workflow discovery
- schema validation failure
- run list rendering
- generic block rendering
- action submission
- local database persistence
- event stream ingestion

## Hermes Mock Tests

Before real Hermes integration, use a mock Hermes server that can:

- list workflows
- start document onboarding
- emit events
- emit display updates
- create a human task
- accept actions
- emit output metadata

## First End-to-End Test

The first end-to-end test should run document onboarding against a local test matter and prove:

- workflow appears
- run starts
- progress updates render
- human task appears
- approval action works
- output appears
- run completes
