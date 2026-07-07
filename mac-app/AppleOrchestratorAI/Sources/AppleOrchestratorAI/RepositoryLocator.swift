import Foundation

enum RepositoryLocator {
    static func findRepoRoot() -> URL? {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: url.appending(path: "config/apps.json").path) {
                return url
            }
            url.deleteLastPathComponent()
        }

        let packageRelative = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "../..")
            .standardizedFileURL
        if FileManager.default.fileExists(atPath: packageRelative.appending(path: "config/apps.json").path) {
            return packageRelative
        }

        return nil
    }
}
