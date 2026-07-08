import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case voice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voice:
            "Voice"
        }
    }

    var symbolName: String {
        switch self {
        case .voice:
            "mic"
        }
    }
}

enum ModalSurface: String, Identifiable {
    case hermes
    case pi
    case runtime
    case workflows
    case runs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hermes:
            "Hermes"
        case .pi:
            "Pi"
        case .runtime:
            "Runtime"
        case .workflows:
            "Workflows"
        case .runs:
            "Runs"
        }
    }

    var symbolName: String {
        switch self {
        case .hermes:
            "bolt.horizontal"
        case .pi:
            "terminal"
        case .runtime:
            "cpu"
        case .workflows:
            "list.bullet.rectangle"
        case .runs:
            "waveform.path.ecg.rectangle"
        }
    }
}

struct CommandResult: Sendable {
    let exitCode: Int32
    let output: String
}

struct WorkflowCatalogItem: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let status: String
    let domain: String
    let description: String
    let stages: [String]
    let launchModes: [String]
    let humanInteraction: String
    let defaultLocalModel: String
}

struct WorkflowRunRecord: Identifiable, Decodable, Equatable {
    let id: String
    let workflowId: String
    let workflowName: String
    let status: String
    let profileId: String
    let startedAt: String
    let completedAt: String?
    let client: DisplayEntity
    let matter: DisplayEntity
    let stages: [WorkflowStageRecord]
    let humanReview: HumanReviewRecord?
    let outputs: [OutputEnvelope]
    var events: [WorkflowRunEvent] = []

    enum CodingKeys: String, CodingKey {
        case id
        case workflowId
        case workflowName
        case status
        case profileId
        case startedAt
        case completedAt
        case client
        case matter
        case stages
        case humanReview
        case outputs
        case events
    }
}

struct DisplayEntity: Decodable, Equatable {
    let id: String
    let name: String
}

struct WorkflowStageRecord: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let status: String
    let summary: String
}

struct HumanReviewRecord: Decodable, Equatable {
    let id: String
    let status: String
    let title: String
    let summary: String
    let segments: [HumanReviewSegment]
}

struct HumanReviewSegment: Identifiable, Decodable, Equatable {
    let id: String
    let label: String
    let status: String
    let decision: String?
    let summary: String
}

struct OutputEnvelope: Identifiable, Decodable, Equatable {
    let id: String
    let type: String
    let title: String
    let content: String
}

struct WorkflowRunEvent: Identifiable, Decodable, Equatable {
    var id: String {
        "\(timestamp)-\(type)-\(stageId ?? reviewId ?? rawHermesRunId ?? runId)"
    }

    let timestamp: String
    let type: String
    let runId: String
    let workflowId: String?
    let stageId: String?
    let reviewId: String?
    let rawHermesRunId: String?
}
