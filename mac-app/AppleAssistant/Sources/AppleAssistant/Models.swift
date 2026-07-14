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
    case coder
    case personal
    case bookWriter
    case postWriter
    case aiScout
    case golfer
    case companyGrowth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coder:
            "Coder"
        case .personal:
            "Personal"
        case .bookWriter:
            "Book Writer"
        case .postWriter:
            "Post Writer"
        case .aiScout:
            "AI Scout"
        case .golfer:
            "Golfer"
        case .companyGrowth:
            "Company Growth"
        }
    }

    var symbolName: String {
        switch self {
        case .coder:
            "hammer"
        case .personal:
            "person.crop.circle"
        case .bookWriter:
            "book"
        case .postWriter:
            "square.and.pencil"
        case .aiScout:
            "sparkle.magnifyingglass"
        case .golfer:
            "figure.golf"
        case .companyGrowth:
            "chart.line.uptrend.xyaxis"
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
