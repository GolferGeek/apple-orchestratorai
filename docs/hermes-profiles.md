# Hermes Profiles

Hermes profiles are specialized local agents with separate memory, state, skills, and purpose.

The Apple app should present one assistant experience, but internally route work to the correct Hermes profile.

See [Profile Contract](profile-contract.md) for the current profile manifest shape, inference routes, work intake policy, and device/persistence assumptions.

## Profile Set

Committed product profile:

- `legal-dev`: legal workflow/product work and legal workflow execution.

Private local profiles:

- `personal`: personal Apple assistant work.
- `coder`: software effort coordinator for Codex and app-building work.
- `book-writer`: long-form book writing.
- `post-writer`: short-form posts and essays.
- `ai-scout`: AI model/tool/framework scouting.
- `golfer`: golf practice, round planning, course strategy, and improvement tracking.
- `company-growth`: company strategy, growth experiments, positioning, revenue, partnerships, and operating cadence.

No `legal-demo` profile yet. If a clean demo environment becomes useful later, clone from `legal-dev` after the legal pack stabilizes.

## What Goes In Git

Commit:

- product profile manifests under `config/hermes-profiles/`
- generic example memory files under `examples/hermes-memory/`
- profile descriptions
- routing hints
- memory policy templates
- tool permission defaults
- empty/setup templates

Do not commit:

- private user profile manifests under `config/hermes-profiles.local/`
- live Hermes profile homes
- live memory databases
- `SOUL.md` files after personal customization
- session history
- credentials
- real client or matter data
- profile-local logs

Actual profile state belongs under ignored runtime or app support directories.

Private local profile manifests belong under:

```text
config/hermes-profiles.local/
```

That directory is gitignored. It is the right place for profiles that are specific to the user rather than the product.

Generic example memory files belong under:

```text
examples/hermes-memory/
```

Those files are committed because they contain only template/example content. They should show users how to structure `SOUL.md`, `USER.md`, and `MEMORY.md` without including any real private memory.

Development runtime:

```text
.runtime/
  hermes-home/
  hermes-profiles/
```

Packaged app runtime:

```text
~/Library/Application Support/AppleOrchestratorAI/
  Hermes/
  HermesProfiles/
```

## Routing Rule

The app should route obvious requests automatically and ask when ambiguous.

Examples:

```text
"Remind me to..."                         -> personal      local/private
"Run document onboarding for this matter" -> legal-dev     committed/product
"Create an effort for Codex"              -> coder         local/private
"Draft chapter 3"                         -> book-writer   local/private
"Turn this into a LinkedIn post"          -> post-writer   local/private
"Find the best new MLX tool model"        -> ai-scout      local/private
"Plan tomorrow's range session"           -> golfer        local/private
"Evaluate this partnership idea"          -> company-growth local/private
```

The app should support manual override:

```text
Mode: Auto | Personal | Legal Dev | Coder | Book Writer | Post Writer | AI Scout | Golfer | Company Growth
```

## Memory Boundaries

Each profile gets its own memory. This prevents memory bleed:

- personal facts should not leak into legal workflows
- legal matter facts should not influence personal assistant behavior
- coding/build memories should not pollute writing voice
- AI scouting observations should not become legal assumptions

Cross-profile promotion should be explicit. For example, the user can say:

```text
Remember this as a general preference.
Promote this coding decision to the Apple Orchestrator AI project.
Use this AI scout finding in the coder profile.
```

## Private Profiles

Private profiles are still first-class runtime profiles, but their manifests and memory should stay out of git unless they become product templates.

### Coder Profile

`coder` is not just a code-writing profile. It coordinates software efforts.

Responsibilities:

- maintain the effort queue
- convert intentions into Codex work packets
- review app effort inbox items
- create current efforts when an intention is clear enough
- write blocking questions when an intention is not clear enough
- track Codex results
- summarize build/test/commit outcomes
- remember app-specific architecture preferences
- use Pi as a developer/admin harness when helpful

Codex remains the implementation agent. Hermes `coder` is the coordinator and memory layer.

### Personal Profile

`personal` is the default personal Apple assistant mode.

It can remember preferences, routines, projects, and lightweight personal context. It should not absorb legal matter facts or repo implementation details unless the user explicitly promotes them.

### Company Growth Profile

`company-growth` is a private business strategy and operating profile.

Responsibilities:

- growth experiments
- product and market positioning
- sales and partnership ideas
- operating cadence and decision logs
- explicit handoff to `coder` when growth work becomes product implementation

Because this may contain private company context, the manifest and live memory stay under `config/hermes-profiles.local/` or runtime state unless a generic product template is intentionally created.

## Product Profile: Legal Dev

`legal-dev` is both product-development and workflow-execution oriented.

Responsibilities:

- legal workflow JSON
- legal skills
- test matters
- legal document workflows
- human-in-the-loop review structures
- matter/resource binding assumptions

It may handle real legal work later, but only inside explicitly attached safe local matter workspaces.

## Implementation Notes

Hermes supports profile commands:

```bash
hermes profile list
hermes profile create <name>
hermes profile describe <name> --text "<description>"
hermes profile use <name>
hermes profile show <name>
```

The Apple app should not rely only on sticky global `hermes profile use`. It should launch or address Hermes through an explicit app-level profile selection so routing is deterministic.
