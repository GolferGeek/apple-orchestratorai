import Foundation

struct OllamaClient {
    private let session: URLSession
    private let sharedBaseURL = URL(string: "http://127.0.0.1:11435")!
    private let systemBaseURL = URL(string: "http://127.0.0.1:11434")!
    private let defaultModel = "qwen3.6:35b-a3b-nvfp4"
    private let optimizedModelNames = [
        "qwen3.6:35b-a3b-nvfp4",
        "qwen3.6:35b-a3b-coding-nvfp4",
        "gemma4:e4b-mlx",
        "gemma4:e2b-mlx"
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func status() async -> OllamaStatus {
        async let sharedTask = endpointStatus(id: "ollama-shared", baseURL: sharedBaseURL)
        async let systemTask = endpointStatus(id: "ollama-system", baseURL: systemBaseURL)
        async let modelsTask = optimizedModels()

        return await OllamaStatus(
            sharedEndpoint: sharedTask,
            systemEndpoint: systemTask,
            selectedDefaultModel: defaultModel,
            optimizedModels: modelsTask
        )
    }

    private func endpointStatus(id: String, baseURL: URL) async -> OllamaEndpointStatus {
        do {
            let version: OllamaVersionResponse = try await get(baseURL.appending(path: "api/version"))
            return OllamaEndpointStatus(
                id: id,
                baseURL: baseURL.absoluteString,
                status: .ok,
                detail: "Ollama \(version.version)"
            )
        } catch {
            return OllamaEndpointStatus(
                id: id,
                baseURL: baseURL.absoluteString,
                status: .warning,
                detail: error.localizedDescription
            )
        }
    }

    private func optimizedModels() async -> [OllamaModelSummary] {
        do {
            let response: OllamaTagsResponse = try await get(sharedBaseURL.appending(path: "api/tags"))
            return response.models
                .filter { optimizedModelNames.contains($0.name) }
                .sorted { lhs, rhs in
                    (optimizedModelNames.firstIndex(of: lhs.name) ?? Int.max) < (optimizedModelNames.firstIndex(of: rhs.name) ?? Int.max)
                }
                .map {
                    OllamaModelSummary(
                        id: $0.name,
                        name: $0.name,
                        size: ByteCountFormatter.string(fromByteCount: Int64($0.size), countStyle: .file),
                        modified: $0.modifiedAt ?? "Installed"
                    )
                }
        } catch {
            return []
        }
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw OllamaClientError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct OllamaVersionResponse: Decodable {
    let version: String
}

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaModelResponse]
}

private struct OllamaModelResponse: Decodable {
    let name: String
    let modifiedAt: String?
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
    }
}

private enum OllamaClientError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "Ollama returned an invalid response."
    }
}
