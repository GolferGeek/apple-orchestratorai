import Foundation

struct HermesDisplayClient {
    private let runClient: HermesRunClient
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:8642")!,
        apiKey: String = "apple-orchestratorai-local-dev",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.runClient = HermesRunClient(baseURL: baseURL, apiKey: apiKey, session: session)
    }

    func listLegalSourceOptions(kind: LegalSourceKind, parentId: String? = nil) async throws -> [LegalSourceOption] {
        let prompt = Self.prompt(kind: kind, parentId: parentId)
        let response = try await runClient.startRun(
            input: prompt,
            model: "qwen3.6:35b-a3b-nvfp4",
            sessionId: "apple-orchestratorai-legal-source-picker"
        )

        let output = try await waitForOutput(runId: response.runId)
        return try Self.decodePickerOptions(output: output, expectedKind: kind)
    }

    func explainWorkflow(_ workflow: WorkflowCatalogItem, targetType: String = "workflow", targetId: String? = nil) async throws -> WorkflowExplanation {
        let response = try await runClient.startRun(
            input: Self.explanationPrompt(workflow: workflow, targetType: targetType, targetId: targetId ?? workflow.id),
            model: workflow.defaultLocalModel,
            sessionId: "apple-orchestratorai-workflow-explanations"
        )

        let output = try await waitForOutput(runId: response.runId)
        return try Self.decodeWorkflowExplanation(output: output)
    }

    private func waitForOutput(runId: String) async throws -> String {
        for _ in 0..<90 {
            var request = URLRequest(url: baseURL.appending(path: "v1/runs/\(runId)"))
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw HermesDisplayClientError.invalidResponse
            }

            let run = try JSONDecoder().decode(HermesRunStatusResponse.self, from: data)
            if run.status == "completed" {
                return run.output ?? ""
            }
            if ["failed", "cancelled", "stopped"].contains(run.status) {
                throw HermesDisplayClientError.runFailed(run.status)
            }

            try await Task.sleep(for: .seconds(1))
        }

        throw HermesDisplayClientError.timeout
    }

    private static func decodePickerOptions(output: String, expectedKind: LegalSourceKind) throws -> [LegalSourceOption] {
        let text = strippedJSONText(output)
        guard let data = text.data(using: .utf8) else {
            throw HermesDisplayClientError.invalidJSON
        }

        let envelope = try JSONDecoder().decode(PickerOptionsEnvelope.self, from: data)
        return envelope.items.map {
            LegalSourceOption(
                id: $0.id,
                label: $0.label,
                subtitle: $0.subtitle,
                kind: expectedKind,
                source: envelope.source
            )
        }
    }

    private static func decodeWorkflowExplanation(output: String) throws -> WorkflowExplanation {
        let text = strippedJSONText(output)
        guard let data = text.data(using: .utf8) else {
            throw HermesDisplayClientError.invalidJSON
        }

        return try JSONDecoder().decode(WorkflowExplanation.self, from: data)
    }

    private static func strippedJSONText(_ output: String) -> String {
        var text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if lines.first?.hasPrefix("```") == true {
                lines.removeFirst()
            }
            if lines.last?.hasPrefix("```") == true {
                lines.removeLast()
            }
            text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func prompt(kind: LegalSourceKind, parentId: String?) -> String {
        let parentClause = parentId.map { " Parent id: \($0)." } ?? ""
        return """
        You are Hermes providing picker options to the Apple Orchestrator AI Mac app.
        The frontend must not query client, matter, or document stores directly.
        Return ONLY valid one-line JSON with shape:
        {"kind":"picker.options","source":"legal-matter-source","items":[{"id":"string","label":"string","subtitle":"string"}]}
        Request: list \(kind.rawValue).\(parentClause)
        Use the demo Acme Robotics legal source if no external MCP source is configured.
        """
    }

    private static func explanationPrompt(workflow: WorkflowCatalogItem, targetType: String, targetId: String) -> String {
        """
        You are Hermes explaining an Apple Orchestrator AI workflow to a lawyer or legal student.
        Return ONLY valid one-line JSON with this exact shape:
        {"schema_version":"0.1","kind":"workflow.explanation","workflow_id":"\(workflow.id)","target":{"type":"\(targetType)","id":"\(targetId)"},"title":"string","summary":"string","sections":[{"heading":"string","items":["string"]}],"actions":[{"id":"request_change","label":"Request Change"},{"id":"show_related_outputs","label":"Show Outputs"}]}
        Explain what it does, what it needs, what it produces, and where human review happens.
        Do not expose raw workflow JSON as the primary answer.
        Workflow name: \(workflow.name)
        Workflow description: \(workflow.description)
        Stages: \(workflow.stages.joined(separator: ", "))
        Human interaction: \(workflow.humanInteraction)
        """
    }
}

private struct PickerOptionsEnvelope: Decodable {
    let kind: String
    let source: String
    let items: [PickerOption]

    struct PickerOption: Decodable {
        let id: String
        let label: String
        let subtitle: String
    }
}

enum HermesDisplayClientError: LocalizedError {
    case invalidResponse
    case invalidJSON
    case runFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Hermes returned an invalid picker response."
        case .invalidJSON:
            "Hermes did not return valid picker JSON."
        case .runFailed(let status):
            "Hermes picker run ended with status \(status)."
        case .timeout:
            "Hermes picker run timed out."
        }
    }
}
