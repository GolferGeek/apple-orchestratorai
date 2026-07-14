import Foundation

struct WorkflowRunStore {
    func load(repoRoot: URL?) -> [WorkflowRunRecord] {
        guard let repoRoot else { return [] }

        let runtimeRoot = repoRoot.appending(path: ".runtime/apple-local-state", directoryHint: .isDirectory)
        let roots = [
            runtimeRoot.appending(path: "runs", directoryHint: .isDirectory),
            repoRoot.appending(path: "test-fixtures", directoryHint: .isDirectory)
        ]

        return roots
            .flatMap { loadRuns(root: $0, eventsRoot: runtimeRoot.appending(path: "events", directoryHint: .isDirectory)) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private func loadRuns(root: URL, eventsRoot: URL) -> [WorkflowRunRecord] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" }
            .compactMap { loadRun(from: $0, eventsRoot: eventsRoot) }
    }

    private func loadRun(from url: URL, eventsRoot: URL) -> WorkflowRunRecord? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        guard var run = try? JSONDecoder().decode(WorkflowRunRecord.self, from: data) else {
            return nil
        }

        let sidecarEvents = url.deletingPathExtension().appendingPathExtension("events.jsonl")
        run.events = loadEvents(runId: run.id, eventsRoot: eventsRoot)
        if run.events.isEmpty {
            run.events = loadEvents(from: sidecarEvents)
        }
        return run
    }

    private func loadEvents(runId: String, eventsRoot: URL) -> [WorkflowRunEvent] {
        loadEvents(from: eventsRoot.appending(path: "\(runId).jsonl"))
    }

    private func loadEvents(from url: URL) -> [WorkflowRunEvent] {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        return text
            .split(separator: "\n")
            .compactMap { line -> WorkflowRunEvent? in
                guard let lineData = String(line).data(using: .utf8) else { return nil }
                return try? decoder.decode(WorkflowRunEvent.self, from: lineData)
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func appendEvent(_ event: WorkflowRunEvent, repoRoot: URL?) {
        guard let repoRoot else { return }

        let eventsRoot = repoRoot.appending(path: ".runtime/apple-local-state/events", directoryHint: .isDirectory)
        let url = eventsRoot.appending(path: "\(event.runId).jsonl")
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: eventsRoot, withIntermediateDirectories: true)

        guard let data = try? JSONEncoder().encode(event), let line = String(data: data, encoding: .utf8) else {
            return
        }

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: url) else {
            return
        }

        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        if let lineData = (line + "\n").data(using: .utf8) {
            try? handle.write(contentsOf: lineData)
        }
    }

    func saveRun(_ run: WorkflowRunRecord, repoRoot: URL?) {
        guard let repoRoot else { return }

        let runsRoot = repoRoot.appending(path: ".runtime/apple-local-state/runs", directoryHint: .isDirectory)
        let url = runsRoot.appending(path: "\(run.id).json")
        try? FileManager.default.createDirectory(at: runsRoot, withIntermediateDirectories: true)

        guard let data = try? JSONEncoder().encode(run) else {
            return
        }

        try? data.write(to: url, options: [.atomic])
    }
}
