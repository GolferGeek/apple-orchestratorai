import Foundation

struct ReadinessReport: Equatable {
    var generatedAt: Date
    var checks: [ReadinessCheck]

    static let empty = ReadinessReport(generatedAt: Date(), checks: [])

    var status: ReadinessStatus {
        if checks.contains(where: { $0.status == .missing || $0.status == .failed }) {
            return .needsAttention
        }
        if checks.contains(where: { $0.status == .warning }) {
            return .warning
        }
        return .ok
    }
}

struct ReadinessCheck: Identifiable, Equatable {
    let id: String
    let label: String
    let status: ReadinessStatus
    let detail: String
}

enum ReadinessStatus: String, Codable {
    case ok
    case warning
    case missing
    case failed
    case needsAttention = "needs-attention"

    var displayName: String {
        switch self {
        case .ok: "OK"
        case .warning: "Warning"
        case .missing: "Missing"
        case .failed: "Failed"
        case .needsAttention: "Needs Attention"
        }
    }
}

struct RuntimeManifest: Decodable {
    let schemaVersion: String
    let app: ManifestApp
    let runtimes: [ManifestRuntime]
    let profiles: [ManifestProfile]
    let workflowRoots: [String]
    let skillRoots: [String]
}

struct ManifestApp: Decodable {
    let id: String
    let name: String
    let primaryPlatform: String
}

struct ManifestRuntime: Decodable, Identifiable {
    let id: String
    let required: Bool
    let managedBy: String
    let runtimeRoot: String?
    let defaultBaseUrl: String?
    let expectedInterfaces: [String]
    let responsibilities: [String]
}

struct ManifestProfile: Decodable, Identifiable {
    let id: String
    let required: Bool
    let responsibilities: [String]
}

struct WorkflowDefinition: Decodable {
    let schemaVersion: String
    let id: String
    let name: String
    let domain: String
    let version: String
    let status: String
    let summary: String
}

struct WorkflowSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let domain: String
    let version: String
    let status: String
    let summary: String
    let path: String
}

struct HermesAPIStatus: Equatable {
    let baseURL: String
    var health: HermesHealthStatus
    var capabilities: HermesEndpointSummary?
    var models: HermesEndpointSummary?
    var skills: HermesEndpointSummary?
    var toolsets: HermesEndpointSummary?
}

enum HermesHealthStatus: Equatable {
    case online(String, String?)
    case offline(String)

    var readinessStatus: ReadinessStatus {
        switch self {
        case .online:
            .ok
        case .offline:
            .warning
        }
    }

    var displayName: String {
        switch self {
        case .online:
            "Online"
        case .offline:
            "Offline"
        }
    }

    var detail: String {
        switch self {
        case .online(let status, let version):
            if let version {
                return "\(status), version \(version)"
            }
            return status
        case .offline(let reason):
            return reason
        }
    }
}

struct HermesEndpointSummary: Identifiable, Equatable {
    var id: String { path }
    let path: String
    let status: ReadinessStatus
    let detail: String
}

struct HermesRunSummary: Identifiable, Equatable {
    let id: String
    var status: String
    var prompt: String
    var detail: String
}

struct OllamaStatus: Equatable {
    var sharedEndpoint: OllamaEndpointStatus
    var systemEndpoint: OllamaEndpointStatus
    var selectedDefaultModel: String
    var optimizedModels: [OllamaModelSummary]
}

struct OllamaEndpointStatus: Identifiable, Equatable {
    let id: String
    let baseURL: String
    let status: ReadinessStatus
    let detail: String
}

struct OllamaModelSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let size: String
    let modified: String
}
