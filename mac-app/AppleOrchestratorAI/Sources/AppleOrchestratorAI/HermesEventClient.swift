import Foundation

struct HermesEventClient {
    let baseURL: URL
    let apiKey: String
    let session: URLSession

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:8642")!,
        apiKey: String = "apple-orchestratorai-local-dev",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    func streamEvents(runId: String, onEvent: @escaping @Sendable (WorkflowRunEvent) async -> Void) async throws {
        var request = URLRequest(url: baseURL.appending(path: "v1/runs/\(runId)/events"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60 * 60

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw HermesEventClientError.invalidResponse
        }

        var eventName: String?
        var dataLines: [String] = []

        for try await rawLine in bytes.lines {
            let line = rawLine.trimmingCharacters(in: .newlines)

            if line.isEmpty {
                if let event = makeEvent(runId: runId, eventName: eventName, payload: dataLines.joined(separator: "\n")) {
                    await onEvent(event)
                }
                eventName = nil
                dataLines.removeAll()
                continue
            }

            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces))
            } else if line.first == "{" {
                if let event = makeEvent(runId: runId, eventName: nil, payload: line) {
                    await onEvent(event)
                }
            }
        }
    }

    private func makeEvent(runId: String, eventName: String?, payload: String) -> WorkflowRunEvent? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let object = decodeObject(trimmed)
        let type = eventName
            ?? object?["type"] as? String
            ?? object?["event"] as? String
            ?? object?["last_event"] as? String
            ?? "message"

        return WorkflowRunEvent(
            timestamp: object?["timestamp"] as? String ?? Self.timestamp(),
            type: type,
            runId: object?["run_id"] as? String ?? object?["runId"] as? String ?? runId,
            workflowId: object?["workflow_id"] as? String ?? object?["workflowId"] as? String,
            stageId: object?["stage_id"] as? String ?? object?["stageId"] as? String,
            graphId: object?["graph_id"] as? String ?? object?["graphId"] as? String,
            subgraphId: object?["subgraph_id"] as? String ?? object?["subgraphId"] as? String,
            workUnitId: object?["work_unit_id"] as? String ?? object?["workUnitId"] as? String,
            skillId: object?["skill_id"] as? String ?? object?["skillId"] as? String,
            reviewId: object?["review_id"] as? String ?? object?["reviewId"] as? String,
            status: object?["status"] as? String,
            summary: object?["summary"] as? String,
            message: object?["message"] as? String,
            progress: decode(object?["progress"]),
            metrics: decode(object?["metrics"]),
            outputs: decodeOutputs(object?["outputs"]),
            raw: object.map(Self.workflowEventObject),
            rawHermesRunId: object?["run_id"] as? String ?? runId
        )
    }

    private func decodeObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func decode<T: Decodable>(_ value: Any?) -> T? {
        guard let value, JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func decodeOutputs(_ value: Any?) -> [WorkflowEventOutput]? {
        decode(value)
    }

    private static func workflowEventObject(_ object: [String: Any]) -> [String: WorkflowEventValue] {
        object.reduce(into: [:]) { result, pair in
            result[pair.key] = workflowEventValue(pair.value)
        }
    }

    private static func workflowEventValue(_ value: Any) -> WorkflowEventValue {
        switch value {
        case is NSNull:
            return .null
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .number(Double(value))
        case let value as Double:
            return .number(value)
        case let value as String:
            return .string(value)
        case let value as [String: Any]:
            return .object(workflowEventObject(value))
        case let value as [Any]:
            return .array(value.map(workflowEventValue))
        default:
            return .string(String(describing: value))
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

enum HermesEventClientError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "Hermes event stream returned an invalid response."
    }
}
