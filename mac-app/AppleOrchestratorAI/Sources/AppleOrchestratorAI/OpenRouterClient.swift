import Foundation

struct OpenRouterClient {
    func fetchModels(apiKey: String?) async throws -> [OpenRouterModel] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Apple Orchestrator AI", forHTTPHeaderField: "X-Title")
        if let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(OpenRouterModelResponse.self, from: data).data
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
