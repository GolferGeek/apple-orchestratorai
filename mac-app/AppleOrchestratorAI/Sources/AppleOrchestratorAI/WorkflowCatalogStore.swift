import Foundation

struct WorkflowCatalogStore {
    func load(repoRoot: URL?) -> [WorkflowCatalogItem] {
        guard let repoRoot else { return [] }
        let workflowRoot = repoRoot.appending(path: "workflows", directoryHint: .isDirectory)
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: workflowRoot, includingPropertiesForKeys: nil) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" }
            .compactMap(loadWorkflow)
            .sorted { $0.name < $1.name }
    }

    func loadExecutionPlans(repoRoot: URL?) -> [String: WorkflowExecutionPlan] {
        guard let repoRoot else { return [:] }
        let workflowRoot = repoRoot.appending(path: "workflows", directoryHint: .isDirectory)
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: workflowRoot, includingPropertiesForKeys: nil) else {
            return [:]
        }

        let plans = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent.hasSuffix(".execution-plan.json") }
            .compactMap(loadExecutionPlan)

        return Dictionary(uniqueKeysWithValues: plans.map { ($0.workflowId, $0) })
    }

    private func loadWorkflow(from url: URL) -> WorkflowCatalogItem? {
        guard
            let data = try? Data(contentsOf: url),
            let workflow = try? JSONDecoder().decode(WorkflowDefinition.self, from: data)
        else {
            return nil
        }

        return WorkflowCatalogItem(
            id: workflow.id,
            name: workflow.name,
            status: workflow.status,
            domain: workflow.domain,
            description: workflow.description,
            stages: workflow.runtime.observability.presentationStages,
            launchModes: workflow.frontend.launchModes.map(\.name),
            humanInteraction: workflow.operatingMode.humanInteraction,
            defaultLocalModel: workflow.modelPolicy.defaultLocalModel
        )
    }

    private func loadExecutionPlan(from url: URL) -> WorkflowExecutionPlan? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(WorkflowExecutionPlan.self, from: data)
    }
}

private struct WorkflowDefinition: Decodable {
    let id: String
    let name: String
    let status: String
    let domain: String
    let description: String
    let operatingMode: OperatingMode
    let frontend: Frontend
    let runtime: Runtime
    let modelPolicy: ModelPolicy

    struct OperatingMode: Decodable {
        let humanInteraction: String
    }

    struct Frontend: Decodable {
        let launchModes: [LaunchMode]
    }

    struct LaunchMode: Decodable {
        let name: String
    }

    struct Runtime: Decodable {
        let observability: Observability
    }

    struct Observability: Decodable {
        let presentationStages: [String]
    }

    struct ModelPolicy: Decodable {
        let defaultLocalModel: String
    }
}
