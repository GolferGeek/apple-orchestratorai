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
    case legalSource

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
        case .legalSource:
            "Legal Source"
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
        case .legalSource:
            "folder.badge.gearshape"
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

struct WorkflowRunRecord: Identifiable, Codable, Equatable {
    let id: String
    let workflowId: String
    let workflowName: String
    var status: String
    let profileId: String
    let startedAt: String
    var completedAt: String?
    let client: DisplayEntity
    let matter: DisplayEntity
    var stages: [WorkflowStageRecord]
    var humanReview: HumanReviewRecord?
    var outputs: [OutputEnvelope]
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

struct DisplayEntity: Codable, Equatable {
    let id: String
    let name: String
}

struct WorkflowStageRecord: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    var status: String
    var summary: String
}

struct HumanReviewRecord: Codable, Equatable {
    let id: String
    let status: String
    let title: String
    let summary: String
    let segments: [HumanReviewSegment]
}

struct HumanReviewSegment: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let status: String
    let decision: String?
    let summary: String
}

struct OutputEnvelope: Identifiable, Codable, Equatable {
    let id: String
    let type: String
    let title: String
    let content: String
}

struct WorkflowRunEvent: Identifiable, Codable, Equatable, Sendable {
    var id: String {
        "\(timestamp)-\(type)-\(workUnitId ?? stageId ?? reviewId ?? rawHermesRunId ?? runId)"
    }

    let timestamp: String
    let type: String
    let runId: String
    let workflowId: String?
    let stageId: String?
    let graphId: String?
    let subgraphId: String?
    let workUnitId: String?
    let skillId: String?
    let reviewId: String?
    let status: String?
    let summary: String?
    let message: String?
    let progress: WorkflowEventProgress?
    let metrics: [String: WorkflowEventValue]?
    let outputs: [WorkflowEventOutput]?
    let raw: [String: WorkflowEventValue]?
    let rawHermesRunId: String?

    init(
        timestamp: String,
        type: String,
        runId: String,
        workflowId: String? = nil,
        stageId: String? = nil,
        graphId: String? = nil,
        subgraphId: String? = nil,
        workUnitId: String? = nil,
        skillId: String? = nil,
        reviewId: String? = nil,
        status: String? = nil,
        summary: String? = nil,
        message: String? = nil,
        progress: WorkflowEventProgress? = nil,
        metrics: [String: WorkflowEventValue]? = nil,
        outputs: [WorkflowEventOutput]? = nil,
        raw: [String: WorkflowEventValue]? = nil,
        rawHermesRunId: String? = nil
    ) {
        self.timestamp = timestamp
        self.type = type
        self.runId = runId
        self.workflowId = workflowId
        self.stageId = stageId
        self.graphId = graphId
        self.subgraphId = subgraphId
        self.workUnitId = workUnitId
        self.skillId = skillId
        self.reviewId = reviewId
        self.status = status
        self.summary = summary
        self.message = message
        self.progress = progress
        self.metrics = metrics
        self.outputs = outputs
        self.raw = raw
        self.rawHermesRunId = rawHermesRunId
    }
}

struct WorkflowEventProgress: Codable, Equatable, Sendable {
    let current: Double
    let total: Double
    let unit: String
}

struct WorkflowEventOutput: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let type: String
    let uri: String?
    let title: String?
}

enum WorkflowEventValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: WorkflowEventValue])
    case array([WorkflowEventValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: WorkflowEventValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([WorkflowEventValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var displayValue: String {
        switch self {
        case .string(let value):
            value
        case .number(let value):
            value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value):
            String(value)
        case .object:
            "object"
        case .array(let value):
            "\(value.count) items"
        case .null:
            "null"
        }
    }
}

enum LegalSourceKind: String, Codable, Equatable {
    case clients
    case matters
    case documents
}

struct LegalSourceOption: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let subtitle: String
    let kind: LegalSourceKind
    let source: String
}

struct LegalSourceSelection: Equatable {
    var client: LegalSourceOption?
    var matter: LegalSourceOption?
    var documents: [LegalSourceOption] = []
}

struct WorkflowExplanation: Identifiable, Codable, Equatable {
    var id: String { workflowId + ":" + target.id }

    let schemaVersion: String
    let kind: String
    let workflowId: String
    let target: WorkflowExplanationTarget
    let title: String
    let summary: String
    let sections: [WorkflowExplanationSection]
    let actions: [WorkflowExplanationAction]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case kind
        case workflowId = "workflow_id"
        case target
        case title
        case summary
        case sections
        case actions
    }
}

struct WorkflowExplanationTarget: Codable, Equatable {
    let type: String
    let id: String
}

struct WorkflowExplanationSection: Identifiable, Codable, Equatable {
    var id: String { heading }

    let heading: String
    let items: [String]
}

struct WorkflowExplanationAction: Identifiable, Codable, Equatable {
    let id: String
    let label: String
}

struct WorkflowLaunchPayload: Encodable {
    let schemaVersion: String
    let kind: String
    let workflowId: String
    let profileId: String
    let launchMode: String
    let classification: String
    let modelPolicy: WorkflowLaunchModelPolicy
    let source: WorkflowLaunchSource
    let outputContracts: [WorkflowLaunchOutputContract]
    let instructions: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case workflowId
        case profileId
        case launchMode
        case classification
        case modelPolicy
        case source
        case outputContracts
        case instructions
    }
}

struct WorkflowLaunchModelPolicy: Encodable {
    let defaultRoute: String
    let sovereignty: String
    let defaultLocalModel: String
    let allowedRoutes: [String]
    let fallbackBehavior: String
}

struct WorkflowLaunchSource: Encodable {
    let resolver: String
    let client: DisplayEntity
    let matter: DisplayEntity
    let documentIds: [String]
    let documentLabels: [String]
    let baseDirectory: String?
    let filePaths: [String]
    let sourceUris: [String]
}

struct WorkflowLaunchOutputContract: Encodable {
    let id: String
    let type: String
    let required: Bool
}
