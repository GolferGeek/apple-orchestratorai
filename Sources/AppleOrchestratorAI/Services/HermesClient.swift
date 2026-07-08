import Foundation

struct HermesClient {
    private let settings: HermesSettings
    private let session: URLSession

    init(settings: HermesSettings = .load(), session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func status() async -> HermesAPIStatus {
        var status = HermesAPIStatus(
            baseURL: settings.baseURL.absoluteString,
            health: .offline("Not checked"),
            capabilities: nil,
            models: nil,
            skills: nil,
            toolsets: nil
        )

        do {
            let health: HermesHealth = try await get("/health", authenticated: false)
            status.health = .online(health.status, health.version)
        } catch {
            status.health = .offline(error.localizedDescription)
            return status
        }

        status.capabilities = await optionalGet("/v1/capabilities")
        status.models = await listSummary(path: "/v1/models", label: "Models")
        status.skills = await listSummary(path: "/v1/skills", label: "Skills")
        status.toolsets = await listSummary(path: "/v1/toolsets", label: "Toolsets")
        return status
    }

    func createRun(input: String, instructions: String? = nil, sessionID: String? = nil, model: String? = nil) async throws -> HermesRunStartResponse {
        let request = HermesRunStartRequest(
            input: input,
            instructions: instructions,
            sessionID: sessionID,
            model: model
        )
        return try await post("/v1/runs", body: request, authenticated: true)
    }

    func runStatus(runID: String) async throws -> HermesRunStatusResponse {
        try await get("/v1/runs/\(runID)", authenticated: true)
    }

    func approveRun(runID: String, choice: HermesApprovalChoice, resolveAll: Bool = false) async throws -> JSONValue {
        let request = HermesApprovalRequest(choice: choice.rawValue, resolveAll: resolveAll)
        return try await post("/v1/runs/\(runID)/approval", body: request, authenticated: true)
    }

    func stopRun(runID: String) async throws -> JSONValue {
        try await post("/v1/runs/\(runID)/stop", body: EmptyRequest(), authenticated: true)
    }

    private func optionalGet(_ path: String) async -> HermesEndpointSummary? {
        do {
            let value: JSONValue = try await get(path, authenticated: true)
            return HermesEndpointSummary(path: path, status: .ok, detail: value.shortDescription)
        } catch {
            return HermesEndpointSummary(path: path, status: .warning, detail: error.localizedDescription)
        }
    }

    private func listSummary(path: String, label: String) async -> HermesEndpointSummary {
        do {
            let value: JSONValue = try await get(path, authenticated: true)
            return HermesEndpointSummary(path: path, status: .ok, detail: "\(label): \(value.listCountDescription)")
        } catch {
            return HermesEndpointSummary(path: path, status: .warning, detail: error.localizedDescription)
        }
    }

    private func get<T: Decodable>(_ path: String, authenticated: Bool) async throws -> T {
        var request = URLRequest(url: settings.baseURL.appending(path: path))
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        return try await send(request: request, authenticated: authenticated)
    }

    private func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body, authenticated: Bool) async throws -> Response {
        var request = URLRequest(url: settings.baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        return try await send(request: request, authenticated: authenticated)
    }

    private func send<T: Decodable>(request originalRequest: URLRequest, authenticated: Bool) async throws -> T {
        var request = originalRequest
        if authenticated {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HermesClientError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct HermesSettings: Equatable {
    let baseURL: URL
    let apiKey: String

    static func load() -> HermesSettings {
        let env = ProcessInfo.processInfo.environment
        let parsedEnv = parseEnvFile(ProjectPaths.root.appending(path: ".runtime/hermes-env.sh"))

        let host = env["API_SERVER_HOST"] ?? parsedEnv["API_SERVER_HOST"] ?? "127.0.0.1"
        let port = env["API_SERVER_PORT"] ?? parsedEnv["API_SERVER_PORT"] ?? "8642"
        let key = env["API_SERVER_KEY"] ?? parsedEnv["API_SERVER_KEY"] ?? "apple-orchestratorai-local-dev"
        let url = URL(string: "http://\(host):\(port)") ?? URL(string: "http://127.0.0.1:8642")!

        return HermesSettings(baseURL: url, apiKey: key)
    }

    private static func parseEnvFile(_ url: URL) -> [String: String] {
        guard let contents = try? String(contentsOf: url) else {
            return [:]
        }

        var values: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("export ") else {
                continue
            }

            let assignment = trimmed.dropFirst("export ".count)
            guard let equals = assignment.firstIndex(of: "=") else {
                continue
            }

            let key = String(assignment[..<equals])
            var value = String(assignment[assignment.index(after: equals)...])
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            values[key] = value
        }

        return values
    }
}

struct HermesHealth: Decodable {
    let status: String
    let version: String?
}

struct HermesRunStartRequest: Encodable {
    let input: String
    let instructions: String?
    let sessionID: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case input
        case instructions
        case sessionID = "session_id"
        case model
    }
}

struct HermesRunStartResponse: Decodable, Equatable {
    let runID: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case status
    }
}

struct HermesRunStatusResponse: Decodable, Equatable {
    let object: String?
    let runID: String
    let status: String
    let updatedAt: Double?
    let output: String?
    let error: String?
    let lastEvent: String?

    enum CodingKeys: String, CodingKey {
        case object
        case runID = "run_id"
        case status
        case updatedAt = "updated_at"
        case output
        case error
        case lastEvent = "last_event"
    }
}

struct HermesApprovalRequest: Encodable {
    let choice: String
    let resolveAll: Bool

    enum CodingKeys: String, CodingKey {
        case choice
        case resolveAll = "resolve_all"
    }
}

struct EmptyRequest: Encodable {}

enum HermesApprovalChoice: String {
    case once
    case session
    case always
    case deny
}

enum HermesClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Hermes returned an invalid response."
        case .httpStatus(let status):
            "Hermes returned HTTP \(status)."
        }
    }
}
