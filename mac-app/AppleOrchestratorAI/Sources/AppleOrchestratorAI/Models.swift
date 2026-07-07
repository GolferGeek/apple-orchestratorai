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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hermes:
            "Hermes"
        case .pi:
            "Pi"
        }
    }

    var symbolName: String {
        switch self {
        case .hermes:
            "bolt.horizontal"
        case .pi:
            "terminal"
        }
    }
}

struct CommandResult: Sendable {
    let exitCode: Int32
    let output: String
}
