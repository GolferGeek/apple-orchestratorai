# Open Questions

- Is the Mac app SwiftUI-only, or does it include a local web view for early velocity?
- Should the local database be SwiftData, SQLite, Core Data, or another embedded store?
- How exactly is Hermes bundled and upgraded?
- Where do workflow packs live on disk?
- How are user-edited workflow JSON files validated?
- How do we sign or trust installed workflow packs?
- How do iPhone and iPad discover the Mac execution node?
- What is the first legal workflow to implement?
- What Ollama MLX models are required for the first build?
- What exact local folder layout should Hermes use?
- Should schemas be generated from JSON Schema into Swift/TypeScript or hand-maintained first?
- What is the minimum acceptable device pairing flow for the iPhone controller?
- Does the Apple app talk directly to Hermes' API server, or through a very thin local adapter process owned by the app?
- Which Hermes API-server version should be the minimum supported bundled runtime?
- What additional workflow-catalog endpoints or skills are needed beyond Hermes' existing `/v1/skills`, `/v1/toolsets`, `/api/sessions`, and `/v1/runs` surfaces?
