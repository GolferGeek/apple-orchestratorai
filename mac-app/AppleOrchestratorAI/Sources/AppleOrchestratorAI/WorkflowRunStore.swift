import Foundation

struct WorkflowRunStore {
    func load(repoRoot: URL?) -> [WorkflowRunRecord] {
        guard let repoRoot else { return [] }

        let roots = [
            repoRoot.appending(path: ".runtime/apple-local-state/runs", directoryHint: .isDirectory),
            repoRoot.appending(path: "test-fixtures", directoryHint: .isDirectory)
        ]

        return roots
            .flatMap(loadRuns)
            .sorted { $0.startedAt > $1.startedAt }
    }

    private func loadRuns(root: URL) -> [WorkflowRunRecord] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" }
            .compactMap(loadRun)
    }

    private func loadRun(from url: URL) -> WorkflowRunRecord? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(WorkflowRunRecord.self, from: data)
    }
}
