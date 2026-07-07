import Foundation

enum EffortIntentReader {
    static func currentEffortSummary() -> String {
        guard let repoRoot = RepositoryLocator.findRepoRoot() else {
            return "I cannot find the Apple Orchestrator AI repository yet."
        }

        let currentRoot = repoRoot.appending(path: "apps/apple-orchestratorai/efforts/current")
        let inboxRoot = repoRoot.appending(path: "apps/apple-orchestratorai/efforts/inbox")
        let currentEfforts = effortDirectories(at: currentRoot)

        if let first = currentEfforts.first {
            let title = effortTitle(at: first)
            let turn = turnSummary(at: first)
            return "Your current effort is \(title). \(turn)"
        }

        let inboxCount = markdownFiles(at: inboxRoot).count
        if inboxCount == 1 {
            return "You do not have a current effort yet. There is one intention waiting in the inbox."
        }
        return "You do not have a current effort yet. There are \(inboxCount) intentions waiting in the inbox."
    }

    static func overallStatusSummary() -> String {
        guard let repoRoot = RepositoryLocator.findRepoRoot() else {
            return "I cannot find the Apple Orchestrator AI repository yet."
        }

        let effortsRoot = repoRoot.appending(path: "apps/apple-orchestratorai/efforts")
        let inbox = markdownFiles(at: effortsRoot.appending(path: "inbox")).count
        let current = effortDirectories(at: effortsRoot.appending(path: "current")).count
        let future = effortDirectories(at: effortsRoot.appending(path: "future")).count
        let archive = effortDirectories(at: effortsRoot.appending(path: "archive")).count

        if current == 0 {
            return "No efforts are currently running. Inbox: \(inbox). Future: \(future). Archive: \(archive)."
        }

        return "You have \(current) current effort\(current == 1 ? "" : "s"). Inbox: \(inbox). Future: \(future). Archive: \(archive)."
    }

    private static func effortDirectories(at url: URL) -> [URL] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return urls.filter { item in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
                && item.lastPathComponent != ".gitkeep"
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func markdownFiles(at url: URL) -> [URL] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func effortTitle(at url: URL) -> String {
        let intention = url.appending(path: "intention.md")
        guard let text = try? String(contentsOf: intention, encoding: .utf8) else {
            return url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
        }

        for line in text.split(separator: "\n") {
            if line.hasPrefix("# ") {
                return line
                    .dropFirst(2)
                    .replacingOccurrences(of: "Effort: ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
    }

    private static func turnSummary(at url: URL) -> String {
        let metadata = url.appending(path: "effort.json")
        guard
            let data = try? Data(contentsOf: metadata),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let turn = json["turn"] as? [String: Any]
        else {
            return "No turn owner is recorded yet."
        }

        let owner = turn["owner"] as? String ?? "unknown"
        let state = turn["state"] as? String ?? "unknown"
        let reason = turn["reason"] as? String ?? ""

        if reason.isEmpty {
            return "It is \(owner)'s turn, and the state is \(state)."
        }
        return "It is \(owner)'s turn, and the state is \(state). \(reason)"
    }
}
