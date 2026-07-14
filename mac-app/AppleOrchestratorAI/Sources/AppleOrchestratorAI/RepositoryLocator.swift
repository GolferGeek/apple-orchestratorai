import Foundation

enum RepositoryLocator {
    static func findRepoRoot() -> URL? {
        if let override = ProcessInfo.processInfo.environment["APPLE_ORCHESTRATORAI_REPO_ROOT"] {
            let url = URL(fileURLWithPath: override).standardizedFileURL
            if isRepoRoot(url) {
                return url
            }
        }

        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            Bundle.main.bundleURL,
            Bundle.main.executableURL
        ].compactMap { $0?.standardizedFileURL }

        for candidate in candidates {
            if let repoRoot = findRepoRoot(from: candidate) {
                return repoRoot
            }
        }

        return nil
    }

    private static func findRepoRoot(from start: URL) -> URL? {
        var url = start
        if url.hasDirectoryPath == false {
            url.deleteLastPathComponent()
        }

        for _ in 0..<12 {
            if isRepoRoot(url) {
                return url
            }
            let previous = url
            url.deleteLastPathComponent()
            if url == previous {
                break
            }
        }

        return nil
    }

    private static func isRepoRoot(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appending(path: "config/apps.json").path)
    }
}
