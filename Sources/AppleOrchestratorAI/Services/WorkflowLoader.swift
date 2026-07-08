import Foundation

struct WorkflowLoader {
    func load() async -> [WorkflowSummary] {
        let root = ProjectPaths.legalWorkflowRoot
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }

        var summaries: [WorkflowSummary] = []

        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "json" else {
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let definition = try JSONDecoder().decode(WorkflowDefinition.self, from: data)
                summaries.append(
                    WorkflowSummary(
                        id: definition.id,
                        name: definition.name,
                        domain: definition.domain,
                        version: definition.version,
                        status: definition.status,
                        summary: definition.summary,
                        path: url.path
                    )
                )
            } catch {
                continue
            }
        }

        return summaries.sorted { $0.name < $1.name }
    }
}
