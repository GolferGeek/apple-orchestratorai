import Foundation

enum ProjectPaths {
    static var root: URL {
        if let configured = ProcessInfo.processInfo.environment["APPLE_ORCHESTRATOR_ROOT"],
           !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    static var runtimeManifest: URL {
        root.appending(path: "runtime/runtime-manifest.json")
    }

    static var legalWorkflowRoot: URL {
        root.appending(path: "workflows/legal")
    }
}
