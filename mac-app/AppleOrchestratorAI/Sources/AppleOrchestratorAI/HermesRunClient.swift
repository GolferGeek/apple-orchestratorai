import Foundation

struct HermesRunClient {
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

    func startRun(input: String, model: String, sessionId: String) async throws -> HermesRunStartResponse {
        var request = URLRequest(url: baseURL.appending(path: "v1/runs"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        request.httpBody = try JSONEncoder().encode(HermesRunStartRequest(
            input: input,
            instructions: "Return concise workflow status and emit normal Hermes run events. Do not call external model providers.",
            sessionId: sessionId,
            model: model
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw HermesRunClientError.invalidResponse(String(data: data, encoding: .utf8) ?? "")
        }

        return try JSONDecoder().decode(HermesRunStartResponse.self, from: data)
    }
}

struct HermesRunStartResponse: Decodable {
    let runId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case status
    }
}

private struct HermesRunStartRequest: Encodable {
    let input: String
    let instructions: String
    let sessionId: String
    let model: String

    enum CodingKeys: String, CodingKey {
        case input
        case instructions
        case sessionId = "session_id"
        case model
    }
}

enum HermesRunClientError: LocalizedError {
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let body):
            body.isEmpty ? "Hermes run start returned an invalid response." : body
        }
    }
}
