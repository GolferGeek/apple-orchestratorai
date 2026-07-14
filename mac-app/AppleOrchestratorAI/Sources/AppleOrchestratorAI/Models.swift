import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case runs
    case workflows
    case builderAI
    case legalSource
    case runtime
    case pi
    case hermes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runs:
            "Runs"
        case .workflows:
            "Workflows"
        case .builderAI:
            "Builder AI"
        case .legalSource:
            "Sources"
        case .runtime:
            "Runtime"
        case .pi:
            "Pi"
        case .hermes:
            "Hermes"
        }
    }

    var symbolName: String {
        switch self {
        case .runs:
            "waveform.path.ecg.rectangle"
        case .workflows:
            "person.crop.circle.badge.gearshape"
        case .builderAI:
            "sparkles"
        case .legalSource:
            "folder.badge.gearshape"
        case .runtime:
            "cpu"
        case .pi:
            "terminal"
        case .hermes:
            "bolt.horizontal"
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
    let outputContracts: [WorkflowLaunchOutputContract]
    let brief: WorkflowProductBrief
}

struct WorkflowProductBrief: Decodable, Equatable {
    let overview: String
    let benefits: String
    let userGuide: String
    let adminNotes: String
    let testCases: [WorkflowProductTestCase]

    static let empty = WorkflowProductBrief(
        overview: "No workflow overview has been written yet.",
        benefits: "No workflow benefits have been written yet.",
        userGuide: "Use the workflow's run screen to select sources, review decisions, and final outputs.",
        adminNotes: "Maintain this workflow through the Workflow Agent Builder.",
        testCases: []
    )
}

struct WorkflowProductTestCase: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let goal: String
    let fixture: String
    let expected: String
    let review: String
    let runnable: Bool
}

struct WorkflowAgentNode: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case workflow
        case phase
        case subphase
        case workUnit = "work_unit"
        case workTeam = "work_team"
        case role
        case skill
        case tool
        case output

        var id: String { rawValue }

        var label: String {
            switch self {
            case .workflow: "Workflow Agent"
            case .phase: "Phase"
            case .subphase: "Subphase"
            case .workUnit: "Work Unit"
            case .workTeam: "Work Team"
            case .role: "Role"
            case .skill: "Skill"
            case .tool: "Tool"
            case .output: "Output"
            }
        }

        var symbolName: String {
            switch self {
            case .workflow: "person.crop.circle.badge.gearshape"
            case .phase: "square.stack.3d.up"
            case .subphase: "point.3.connected.trianglepath.dotted"
            case .workUnit: "checklist"
            case .workTeam: "person.3"
            case .role: "person.crop.circle"
            case .skill: "wand.and.stars"
            case .tool: "wrench.and.screwdriver"
            case .output: "doc.richtext"
            }
        }
    }

    var id: String
    var kind: Kind
    var name: String
    var detail: String
    var model: String?
    var required: Bool
    var events: [String]
    var children: [WorkflowAgentNode]
}

struct OpenRouterModel: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let contextLength: Int?
    let pricing: Pricing?
    let architecture: Architecture?

    struct Pricing: Decodable, Equatable {
        let prompt: String?
        let completion: String?
    }

    struct Architecture: Decodable, Equatable {
        let inputModalities: [String]?
        let outputModalities: [String]?
    }

    enum CodingKeys: String, CodingKey {
        case id, name, pricing, architecture
        case contextLength = "context_length"
    }
}

struct OpenRouterModelResponse: Decodable {
    let data: [OpenRouterModel]
}

struct PlannedRunProgress {
    let stages: [PlannedStageProgress]
    let completedWorkUnitCount: Int
    let totalWorkUnitCount: Int
    let latestActiveWorkUnit: PlannedWorkUnitProgress?
}

struct PlannedStageProgress: Identifiable {
    let id: String
    let name: String
    let execution: String
    let graphId: String
    let subgraphId: String?
    let workUnits: [PlannedWorkUnitProgress]

    var status: String {
        if workUnits.allSatisfy({ $0.status == "completed" }) {
            return "completed"
        }
        if workUnits.contains(where: { $0.status == "running" }) {
            return "running"
        }
        if workUnits.contains(where: { $0.status == "started" }) {
            return "started"
        }
        return "defined"
    }
}

struct PlannedWorkUnitProgress: Identifiable {
    let id: String
    let name: String
    let skillId: String
    let optional: Bool
    let status: String
    let lastEventType: String?
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
    var entries: [WorkflowRunEntry] = []

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

struct WorkflowRunEntry: Identifiable, Codable, Equatable {
    var id: String {
        "\(timestamp)-\(entryType)-\(roleId ?? teamId ?? workUnitId ?? runId)"
    }

    let timestamp: String
    let runId: String
    let entryType: String
    let data: [String: WorkflowEventValue]

    var workflowId: String? { data.stringValue("workflowId") }
    var workUnitId: String? { data.stringValue("workUnitId") }
    var teamId: String? { data.stringValue("teamId") }
    var roleId: String? { data.stringValue("roleId") }
    var agentId: String? { data.stringValue("agentId") }
    var skillId: String? { data.stringValue("skillId") }
    var modelName: String? { data.stringValue("model") ?? data.objectValue("details")?.stringValue("model") }

    var previewText: String {
        if let output = data.stringValue("output") {
            return output.strippedCodeFence.truncated(to: 700)
        }

        if let summary = data.stringValue("summary") {
            return summary.truncated(to: 700)
        }

        if let status = data.stringValue("status") {
            return "Status: \(status)"
        }

        if let roleOutputs = data.arrayValue("roleOutputs"), !roleOutputs.isEmpty {
            let roles = roleOutputs.compactMap { value -> String? in
                guard case .object(let object) = value else { return nil }
                let role = object.stringValue("roleId") ?? "role"
                let failed = object.boolValue("failed") == true ? " failed" : ""
                return "\(role)\(failed)"
            }
            return roles.isEmpty ? "\(roleOutputs.count) role outputs" : "Team output: \(roles.joined(separator: ", "))"
        }

        return data
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value.previewValue)" }
            .joined(separator: ", ")
            .truncated(to: 700)
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
        "\(timestamp)-\(type)-\(roleId ?? teamId ?? workUnitId ?? stageId ?? reviewId ?? rawHermesRunId ?? runId)"
    }

    let timestamp: String
    let type: String
    let runId: String
    let workflowId: String?
    let stageId: String?
    let graphId: String?
    let subgraphId: String?
    let workUnitId: String?
    let teamId: String?
    let roleId: String?
    let agentId: String?
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

    var modelName: String? {
        raw?.objectValue("details")?.stringValue("model")
            ?? raw?.stringValue("model")
            ?? metrics?.stringValue("model")
            ?? raw?.objectValue("raw")?.objectValue("message")?.stringValue("model")
            ?? raw?.objectValue("raw")?.objectValue("assistantMessageEvent")?.objectValue("partial")?.stringValue("model")
    }

    var piMessageText: String? {
        if let message = message ?? summary, !message.isEmpty { return message }
        let rawEvent = raw?.objectValue("raw")
        let message = rawEvent?.objectValue("message")
            ?? rawEvent?.objectValue("assistantMessageEvent")?.objectValue("partial")
        guard let content = message?.arrayValue("content") else { return nil }
        let text = content.compactMap { value -> String? in
            guard case .object(let item) = value else { return nil }
            return item.stringValue("text")
        }.joined()
        return text.isEmpty ? nil : text
    }

    var piToolName: String? {
        raw?.objectValue("raw")?.stringValue("toolName")
    }

    var piMessageRole: String? {
        raw?.objectValue("raw")?.objectValue("message")?.stringValue("role")
            ?? raw?.objectValue("raw")?.objectValue("assistantMessageEvent")?.objectValue("partial")?.stringValue("role")
    }

    var isPiToolEvent: Bool {
        type.hasPrefix("tool.") || piToolName != nil
    }

    init(
        timestamp: String,
        type: String,
        runId: String,
        workflowId: String? = nil,
        stageId: String? = nil,
        graphId: String? = nil,
        subgraphId: String? = nil,
        workUnitId: String? = nil,
        teamId: String? = nil,
        roleId: String? = nil,
        agentId: String? = nil,
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
        self.teamId = teamId
        self.roleId = roleId
        self.agentId = agentId
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

    var previewValue: String {
        switch self {
        case .string(let value):
            return value.strippedCodeFence.truncated(to: 180)
        case .number, .bool, .null:
            return displayValue
        case .object(let value):
            let keys = value.keys.sorted().prefix(5).joined(separator: ", ")
            return keys.isEmpty ? "object" : "object(\(keys))"
        case .array(let value):
            return "\(value.count) items"
        }
    }
}

extension Dictionary where Key == String, Value == WorkflowEventValue {
    func stringValue(_ key: String) -> String? {
        guard case .string(let value) = self[key] else { return nil }
        return value
    }

    func boolValue(_ key: String) -> Bool? {
        guard case .bool(let value) = self[key] else { return nil }
        return value
    }

    func arrayValue(_ key: String) -> [WorkflowEventValue]? {
        guard case .array(let value) = self[key] else { return nil }
        return value
    }

    func objectValue(_ key: String) -> [String: WorkflowEventValue]? {
        guard case .object(let value) = self[key] else { return nil }
        return value
    }
}

extension String {
    var strippedCodeFence: String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("```") {
            value = value
                .split(separator: "\n", omittingEmptySubsequences: false)
                .dropFirst()
                .joined(separator: "\n")
        }
        if value.hasSuffix("```") {
            value = String(value.dropLast(3))
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func truncated(to maxLength: Int) -> String {
        guard count > maxLength else { return self }
        let end = index(startIndex, offsetBy: maxLength)
        return String(self[..<end]) + "..."
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

struct LocalWorkflowFile: Identifiable, Equatable {
    let url: URL

    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
    var location: String { url.deletingLastPathComponent().path }
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

struct WorkflowLaunchOutputContract: Codable, Equatable {
    let id: String
    let type: String
    let required: Bool
}

struct WorkflowOutputPacket {
    let items: [WorkflowOutputPacketItem]

    var fulfilledCount: Int {
        items.filter(\.isFulfilled).count
    }
}

struct WorkflowOutputPacketItem: Identifiable {
    let id: String
    let type: String
    let required: Bool
    let output: OutputEnvelope?
    let eventOutput: WorkflowEventOutput?

    var isFulfilled: Bool {
        output != nil || eventOutput != nil
    }

    var title: String {
        output?.title ?? eventOutput?.title ?? id
    }
}
