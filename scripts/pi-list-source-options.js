#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const [kind, parentId = ""] = process.argv.slice(2);
const root = path.resolve(__dirname, "..");
const fixture = JSON.parse(fs.readFileSync(path.join(root, "test-fixtures/legal/document-onboarding/acme-renewal/input.json"), "utf8"));

const documentOptions = fixture.fileSystemDocuments.filePaths.map((filePath, index) => ({
  id: `document-${index + 1}`,
  label: path.basename(filePath),
  subtitle: `Demo legal source · ${fixture.matter.name}`,
}));

const options = {
  clients: [{ id: fixture.client.id, label: fixture.client.name, subtitle: "Demo Pi source adapter" }],
  matters: parentId === fixture.client.id
    ? [{ id: fixture.matter.id, label: fixture.matter.name, subtitle: fixture.matter.jurisdiction ?? "Demo matter" }]
    : [],
  documents: parentId === fixture.matter.id ? documentOptions : [],
}[kind] ?? [];

process.stdout.write(JSON.stringify({
  kind: "picker.options",
  source: "pi.local-demo-adapter",
  items: options,
}));
