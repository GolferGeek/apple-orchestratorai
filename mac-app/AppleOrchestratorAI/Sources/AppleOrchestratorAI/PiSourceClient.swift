import Foundation

struct PiSourceClient {
    func listLegalSourceOptions(kind: LegalSourceKind, parentId: String? = nil, repoRoot: URL?) async throws -> [LegalSourceOption] {
        guard let repoRoot else { throw PiSourceClientError.repositoryUnavailable }
        let output = try await Task.detached(priority: .utility) {
            let result = try Shell.run(
                "/usr/bin/env",
                ["node", "scripts/pi-list-source-options.js", kind.rawValue, parentId ?? ""],
                cwd: repoRoot,
                environment: ["APPLE_ORCHESTRATOR_STATE_DIR": ApplicationDataLocator.stateRoot.path]
            )
            guard result.exitCode == 0 else { throw PiSourceClientError.commandFailed(result.output) }
            return result.output
        }.value

        guard let data = output.data(using: .utf8) else { throw PiSourceClientError.invalidResponse }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.items.map {
            LegalSourceOption(id: $0.id, label: $0.label, subtitle: $0.subtitle, kind: kind, source: envelope.source)
        }
    }

    private struct Envelope: Decodable {
        let source: String
        let items: [Item]

        struct Item: Decodable {
            let id: String
            let label: String
            let subtitle: String
        }
    }
}

enum PiSourceClientError: LocalizedError {
    case repositoryUnavailable
    case invalidResponse
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .repositoryUnavailable: "Could not locate the Pi source bridge."
        case .invalidResponse: "Pi source bridge returned an invalid response."
        case .commandFailed(let detail): "Pi source bridge failed: \(detail)"
        }
    }
}
