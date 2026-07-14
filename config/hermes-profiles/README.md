# Hermes Profile Manifests

This directory contains committed, product-level profile manifests.

Only profiles that are part of the reproducible product should live here. Private user profiles belong in:

```text
config/hermes-profiles.local/
```

That directory is gitignored.

Examples of private user profiles:

- `personal`
- `coder`
- `book-writer`
- `post-writer`
- `ai-scout`

The app can load both directories:

1. committed product profiles from `config/hermes-profiles/`
2. private local profiles from `config/hermes-profiles.local/`

Private profiles should never contain raw credentials, real client data, or live memory exports.

For committed examples of safe memory templates, see:

```text
examples/hermes-memory/
```
