import Foundation

struct WorkflowCatalogStore {
    func load(repoRoot: URL?) -> [WorkflowCatalogItem] {
        let store = WorkflowAgentFileStore()
        return store.agentURLs(repoRoot: repoRoot)
            .compactMap { loadWorkflowAgent(from: $0, store: store) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func loadAgents(repoRoot: URL?) -> [String: WorkflowAgentNode] {
        let store = WorkflowAgentFileStore()
        return Dictionary(uniqueKeysWithValues: store.agentURLs(repoRoot: repoRoot).compactMap { url in
            guard let root = store.load(url: url) else { return nil }
            return (root.id, root)
        })
    }

    private func loadWorkflowAgent(from url: URL, store: WorkflowAgentFileStore) -> WorkflowCatalogItem? {
        guard let root = store.load(url: url) else { return nil }
        let metadata = frontMatter(in: (try? String(contentsOf: url, encoding: .utf8)) ?? "")
        let outputs = flatten(root)
            .filter { $0.kind == .output && $0.name.hasPrefix("outputs.") }
            .map {
            WorkflowLaunchOutputContract(
                id: String($0.name.dropFirst("outputs.".count)),
                type: $0.name.localizedCaseInsensitiveContains("report") ? "export_document" : "structured",
                required: $0.required
            )
            }
        return WorkflowCatalogItem(
            id: root.id,
            name: root.name,
            status: metadata["status"] ?? "dev",
            domain: metadata["domain"] ?? "general",
            description: root.detail,
            stages: root.children.filter { $0.kind == .phase }.map(\.name),
            launchModes: ["Choose Client Matter Documents", "Choose Local Files"],
            humanInteraction: metadata["human_interaction"] ?? "Defined by the workflow agent",
            defaultLocalModel: root.model ?? "inherit",
            outputContracts: outputs,
            brief: WorkflowProductBriefStore().load(url: url)
        )
    }

    private func frontMatter(in text: String) -> [String: String] {
        let lines = text.split(separator: "\n").map(String.init)
        guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else { return [:] }
        return Dictionary(uniqueKeysWithValues: lines[1..<end].compactMap { line in
            let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { return nil }
            return (pair[0].trimmingCharacters(in: .whitespaces), pair[1].trimmingCharacters(in: .whitespaces))
        })
    }

    private func flatten(_ node: WorkflowAgentNode) -> [WorkflowAgentNode] {
        [node] + node.children.flatMap(flatten)
    }
}

struct WorkflowProductBriefStore {
    private let sectionHeading = "## Workflow Product"

    func load(url: URL) -> WorkflowProductBrief {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let section = section(in: text) else {
            return .empty
        }

        let overview = content(under: "### Overview", in: section) ?? WorkflowProductBrief.empty.overview
        let benefits = content(under: "### Benefits", in: section) ?? WorkflowProductBrief.empty.benefits
        let userGuide = content(under: "### User Guide", in: section) ?? WorkflowProductBrief.empty.userGuide
        let adminNotes = content(under: "### Admin", in: section) ?? WorkflowProductBrief.empty.adminNotes
        return WorkflowProductBrief(
            overview: overview,
            benefits: benefits,
            userGuide: userGuide,
            adminNotes: adminNotes,
            testCases: testCases(in: section)
        )
    }

    func preservedSection(in text: String) -> String? {
        section(in: text)
    }

    private func section(in text: String) -> String? {
        guard let start = text.range(of: sectionHeading) else { return nil }
        let remainder = text[start.lowerBound...]
        let searchStart = remainder.index(remainder.startIndex, offsetBy: sectionHeading.count)
        let end = remainder.range(of: "\n## ", options: [], range: searchStart..<remainder.endIndex)
        return String(end.map { remainder[..<$0.lowerBound] } ?? remainder)
    }

    private func content(under heading: String, in section: String) -> String? {
        guard let start = section.range(of: heading) else { return nil }
        let remainder = section[start.upperBound...]
        let end = remainder.range(of: "\n### ")
        let value = String(end.map { remainder[..<$0.lowerBound] } ?? remainder)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func testCases(in section: String) -> [WorkflowProductTestCase] {
        guard let testCaseContent = content(under: "### Test Cases", in: section) else { return [] }
        let parts = testCaseContent.components(separatedBy: "\n#### ").enumerated().compactMap { index, value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if index == 0 { return trimmed.hasPrefix("#### ") ? String(trimmed.dropFirst(5)) : nil }
            return trimmed
        }
        return parts.compactMap { entry in
            let lines = entry.split(separator: "\n").map(String.init)
            guard let name = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            func value(_ key: String) -> String {
                lines.first { $0.hasPrefix("- **\(key):**") }
                    .map { $0.replacingOccurrences(of: "- **\(key):**", with: "").trimmingCharacters(in: .whitespacesAndNewlines) } ?? "Not specified."
            }
            let fixture = value("Fixture").replacingOccurrences(of: "`", with: "")
            return WorkflowProductTestCase(
                id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
                name: name,
                goal: value("Goal"),
                fixture: fixture,
                expected: value("Expected"),
                review: value("Review"),
                runnable: value("Runnable").lowercased() == "yes"
            )
        }
    }
}
