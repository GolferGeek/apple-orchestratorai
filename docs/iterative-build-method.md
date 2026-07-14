# Iterative Build Method

This project should be developed as a repeatable build loop.

The goal is not to write a static spec once and then manually implement everything. The goal is to improve the intention files, schemas, examples, and source files until the project can be rebuilt cleanly and predictably from them.

## Core Idea

The repository should contain enough structured intention that a capable coding agent can build the app, inspect the result, improve the source/intention files, and build again.

This is close to a one-shot build target, but reached through iteration.

```text
Intention files
  product brief
  architecture
  workflow JSON schema
  Hermes contract
  UI block contract
  runtime state model
  legal workflow examples
  build plan

Source files
  Mac app
  Hermes bundle/runtime integration
  local database
  contracts/schemas
  workflow examples
  tests

Build loop
  build
  run
  inspect
  compare against intention
  revise intention/source
  rebuild
```

## What Improves Each Cycle

- The product intention becomes sharper.
- The JSON contracts become more precise.
- The generic UI block model becomes more complete.
- The workflow examples become more realistic.
- The Hermes integration becomes more concrete.
- The local observability model becomes more useful.
- The tests become better expressions of desired behavior.

## Rule

When the build produces the wrong thing, do not only patch the code. First ask whether the intention files were clear enough to produce the right thing.

If not, improve the intention files, then improve the implementation.

## Build Artifacts To Maintain

- `START_HERE.md`
- product brief
- architecture
- workflow JSON schema
- Hermes app contract
- runtime state model
- MCP resource model
- generic UI model
- legal workflow pack
- tests and fixtures

These files are part of the build system conceptually, even when they are Markdown.

## Success Criteria

The project is working when a fresh builder can read `START_HERE.md`, follow the linked files, run the build, and produce a Mac app that:

- discovers workflow JSON files
- starts a workflow through Hermes
- receives live updates
- stores run state locally
- renders generic Hermes UI blocks
- handles human-in-the-loop actions
- displays outputs
- runs at least one legal workflow against a local test matter
