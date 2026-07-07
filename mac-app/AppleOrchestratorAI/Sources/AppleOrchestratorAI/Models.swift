import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case voice
    case hermes
    case pi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voice:
            "Voice"
        case .hermes:
            "Hermes"
        case .pi:
            "Pi"
        }
    }

    var symbolName: String {
        switch self {
        case .voice:
            "mic"
        case .hermes:
            "bolt.horizontal"
        case .pi:
            "terminal"
        }
    }
}

enum ModalSurface: String, Identifiable {
    case coderEfforts
    case personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coderEfforts:
            "Coder Efforts"
        case .personal:
            "Personal"
        }
    }

    var symbolName: String {
        switch self {
        case .coderEfforts:
            "hammer"
        case .personal:
            "person.crop.circle"
        }
    }
}

struct CoderEffortsSurface: Decodable {
    let schemaVersion: String
    let profileId: String
    let surfaceId: String
    let appId: String
    let generatedAt: String
    let sections: EffortSections
}

struct EffortSections: Decodable {
    let inbox: [InboxItem]
    let current: [EffortItem]
    let future: [EffortItem]
    let archive: [EffortItem]
}

struct InboxItem: Decodable, Identifiable {
    let id: String
    let title: String
    let path: String
    let updatedAt: String
    let summary: String?
}

struct EffortItem: Decodable, Identifiable {
    let id: String
    let title: String
    let status: String
    let path: String
    let profileId: String
    let turn: TurnState
    let questionCount: Int
    let hasBlockingQuestions: Bool
    let resultSummary: String?
    let artifactCount: Int
    let updatedAt: String
}

struct TurnState: Decodable {
    let owner: String
    let state: String
    let reason: String
    let since: String?
    let questionIds: [String]?
}

struct CommandResult: Sendable {
    let exitCode: Int32
    let output: String
}
