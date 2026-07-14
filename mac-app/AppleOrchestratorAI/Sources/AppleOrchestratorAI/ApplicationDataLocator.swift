import Foundation

enum ApplicationDataLocator {
    static let applicationName = "Apple Orchestrator AI"

    static var stateRoot: URL {
        let environment = ProcessInfo.processInfo.environment
        if let configured = environment["APPLE_ORCHESTRATOR_STATE_DIR"], !configured.isEmpty {
            return URL(filePath: configured, directoryHint: .isDirectory)
        }

        let supportRoot = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(filePath: NSHomeDirectory()).appending(path: "Library/Application Support", directoryHint: .isDirectory)

        return supportRoot.appending(path: applicationName, directoryHint: .isDirectory)
    }

    static func prepareStateRoot() {
        try? FileManager.default.createDirectory(at: stateRoot, withIntermediateDirectories: true)
    }
}
