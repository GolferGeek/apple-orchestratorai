import Foundation

struct WorkflowRunStore {
    private let maxEntriesPerRun = 120
    private let maxEventsPerRun = 160

    func load(repoRoot: URL?) -> [WorkflowRunRecord] {
        let runtimeRoot = ApplicationDataLocator.stateRoot
        let roots = [runtimeRoot.appending(path: "runs", directoryHint: .isDirectory)]

        return roots
            .flatMap { loadRuns(root: $0, eventsRoot: runtimeRoot.appending(path: "events", directoryHint: .isDirectory)) }
            .reduce(into: [String: WorkflowRunRecord]()) { recordsById, run in
                if let existing = recordsById[run.id] {
                    recordsById[run.id] = richerRun(existing, run)
                } else {
                    recordsById[run.id] = run
                }
            }
            .values
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

        let decoder = JSONDecoder()
        var decodedRun: WorkflowRunRecord?
        if let run = try? decoder.decode(WorkflowRunRecord.self, from: data) {
            decodedRun = run
        } else if let projection = try? decoder.decode(WorkflowRunStatusProjection.self, from: data) {
            decodedRun = projection.asRunRecord()
        }

        guard var run = decodedRun else { return nil }

        let runRoot = url.deletingLastPathComponent()
        let sidecarEvents = runRoot.appending(path: "\(run.id).events.jsonl")
        let sidecarEntries = runRoot.appending(path: "\(run.id).entries.jsonl")
        run.events = loadEvents(runId: run.id, eventsRoot: eventsRoot)
        if run.events.isEmpty {
            run.events = loadEvents(from: sidecarEvents)
        }
        run.entries = loadEntries(from: sidecarEntries)
        let persistedReview = loadHumanReview(from: run.entries) ?? loadHumanReview(fromStatusFile: url)
        if run.humanReview == nil || isPlaceholderReview(run.humanReview) {
            run.humanReview = persistedReview ?? run.humanReview
        }
        run.outputs = mergeOutputs(run.outputs, artifactOutputs(runId: run.id, runtimeRoot: eventsRoot.deletingLastPathComponent()))
        run = normalizedRun(run)
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
            .suffix(maxEventsPerRun)
            .compactMap { line -> WorkflowRunEvent? in
                guard let lineData = String(line).data(using: .utf8) else { return nil }
                return try? decoder.decode(WorkflowRunEvent.self, from: lineData)
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func loadEntries(from url: URL) -> [WorkflowRunEntry] {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        return text
            .split(separator: "\n")
            .suffix(maxEntriesPerRun)
            .compactMap { line -> WorkflowRunEntry? in
                guard let lineData = String(line).data(using: .utf8) else { return nil }
                return try? decoder.decode(WorkflowRunEntry.self, from: lineData)
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func loadHumanReview(from entries: [WorkflowRunEntry]) -> HumanReviewRecord? {
        let richPayload = loadAppleHumanReviewPayload(from: entries)

        guard let request = entries.last(where: { $0.entryType == "human_review.requested" }) else {
            return richPayload?.asHumanReviewRecord(runId: entries.last?.runId)
        }

        let reviewId = request.data.stringValue("reviewId") ?? "review-\(request.runId)"
        let title = request.data.stringValue("title") ?? "Human review requested"

        if let richPayload, !richPayload.reviewItems.isEmpty {
            return richPayload.asHumanReviewRecord(runId: request.runId, reviewId: reviewId, title: title)
        }

        if let filePath = request.data.stringValue("filePath"),
           let projection = loadHumanReviewProjection(from: URL(filePath: filePath)) {
            return projection.asHumanReviewRecord(fallbackId: reviewId, fallbackTitle: title, richPayload: richPayload)
        }

        return HumanReviewRecord(
            id: reviewId,
            status: "requested",
            title: title,
            summary: "Review the workflow output before continuing.",
            segments: [
                HumanReviewSegment(
                    id: "review",
                    label: "Review",
                    status: "pending",
                    decision: nil,
                    summary: "Human review is required."
                )
            ]
        )
    }

    private func loadHumanReview(fromStatusFile url: URL) -> HumanReviewRecord? {
        guard let data = try? Data(contentsOf: url),
              let projection = try? JSONDecoder().decode(WorkflowRunStatusProjection.self, from: data),
              let pendingReview = projection.pendingHumanReview else {
            return nil
        }

        if let filePath = pendingReview.filePath,
           let review = loadHumanReviewProjection(from: URL(filePath: filePath)) {
            return review.asHumanReviewRecord(
                fallbackId: pendingReview.reviewId,
                fallbackTitle: pendingReview.title,
                richPayload: nil
            )
        }

        return HumanReviewRecord(
            id: pendingReview.reviewId,
            status: "requested",
            title: pendingReview.title,
            summary: "Review the workflow output before continuing.",
            segments: [
                HumanReviewSegment(
                    id: "review",
                    label: "Review",
                    status: "decision required",
                    decision: nil,
                    summary: "Human review is required."
                )
            ]
        )
    }

    private func loadHumanReviewProjection(from url: URL) -> HumanReviewProjection? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(HumanReviewProjection.self, from: data)
    }

    private func artifactOutputs(runId: String, runtimeRoot: URL) -> [OutputEnvelope] {
        let artifactRoot = runtimeRoot
            .appending(path: "artifacts", directoryHint: .isDirectory)
            .appending(path: runId, directoryHint: .isDirectory)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: artifactRoot,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files
            .filter { !$0.hasDirectoryPath }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { file in
                OutputEnvelope(
                    id: "artifact-\(file.lastPathComponent)",
                    type: file.pathExtension == "md" ? "markdown" : "file",
                    title: file.lastPathComponent,
                    content: file.path
                )
            }
    }

    private func mergeOutputs(_ existing: [OutputEnvelope], _ discovered: [OutputEnvelope]) -> [OutputEnvelope] {
        var byId: [String: OutputEnvelope] = [:]
        for output in existing {
            byId[output.id] = output
        }
        for output in discovered {
            byId[output.id] = output
        }
        return byId.values.sorted { $0.title < $1.title }
    }

    private func isPlaceholderReview(_ review: HumanReviewRecord?) -> Bool {
        guard let review else { return false }
        return review.segments.count == 1 && review.segments[0].id == "approval"
    }

    private func loadAppleHumanReviewPayload(from entries: [WorkflowRunEntry]) -> AppleHumanReviewPayload? {
        guard let payloadEntry = entries.last(where: { $0.entryType == "human_review.payload" }),
              let output = payloadEntry.data.stringValue("output") else {
            return nil
        }

        let json = output.strippedCodeFence
        guard let data = json.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(AppleHumanReviewPayload.self, from: data)
    }

    func appendEvent(_ event: WorkflowRunEvent, repoRoot: URL?) {
        let eventsRoot = ApplicationDataLocator.stateRoot.appending(path: "events", directoryHint: .isDirectory)
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
        let runsRoot = ApplicationDataLocator.stateRoot.appending(path: "runs", directoryHint: .isDirectory)
        let url = runsRoot.appending(path: "\(run.id).json")
        try? FileManager.default.createDirectory(at: runsRoot, withIntermediateDirectories: true)

        guard let data = try? JSONEncoder().encode(run) else {
            return
        }

        try? data.write(to: url, options: [.atomic])
    }

    func deleteRun(runId: String) {
        let root = ApplicationDataLocator.stateRoot
        let fileManager = FileManager.default
        let exactFiles = [
            root.appending(path: "events/\(runId).jsonl"),
            root.appending(path: "runs/\(runId).json"),
            root.appending(path: "runs/\(runId).status.json"),
            root.appending(path: "runs/\(runId).entries.jsonl"),
            root.appending(path: "runs/\(runId).pid"),
            root.appending(path: "logs/\(runId).log")
        ]
        exactFiles.forEach { try? fileManager.removeItem(at: $0) }

        let exactDirectories = ["artifacts", "documents", "agent-specs", "stage-results", "plans"]
            .map { root.appending(path: "\($0)/\(runId)", directoryHint: .isDirectory) }
        exactDirectories.forEach { try? fileManager.removeItem(at: $0) }

        removePrefixedFiles(in: root.appending(path: "raw-pi-events", directoryHint: .isDirectory), prefix: runId)
        removePrefixedFiles(in: root.appending(path: "human-reviews", directoryHint: .isDirectory), prefix: runId)
    }

    private func removePrefixedFiles(in directory: URL, prefix: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func richerRun(_ lhs: WorkflowRunRecord, _ rhs: WorkflowRunRecord) -> WorkflowRunRecord {
        let lhsReviewCount = lhs.humanReview?.segments.count ?? 0
        let rhsReviewCount = rhs.humanReview?.segments.count ?? 0
        if lhsReviewCount != rhsReviewCount {
            return lhsReviewCount > rhsReviewCount ? lhs : rhs
        }

        if lhs.humanReview?.status != "requested", lhs.humanReview != nil {
            return lhs
        }

        if rhs.humanReview?.status != "requested", rhs.humanReview != nil {
            return rhs
        }

        if !WorkflowRunStatusProjection.activeStatuses.contains(lhs.status), WorkflowRunStatusProjection.activeStatuses.contains(rhs.status) {
            return lhs
        }

        if !WorkflowRunStatusProjection.activeStatuses.contains(rhs.status), WorkflowRunStatusProjection.activeStatuses.contains(lhs.status) {
            return rhs
        }

        let lhsScore = lhs.stages.count + lhs.outputs.count + lhs.events.count + lhs.entries.count
        let rhsScore = rhs.stages.count + rhs.outputs.count + rhs.events.count + rhs.entries.count

        if rhsScore > lhsScore {
            return rhs
        }

        return lhs
    }

    private func normalizedRun(_ run: WorkflowRunRecord) -> WorkflowRunRecord {
        guard ["running", "queued"].contains(run.status), let latestType = run.events.last?.type else {
            return run
        }

        guard latestType == "workflow.completed" || latestType == "run.completed" else {
            return run
        }

        var normalized = run
        normalized.status = "completed"
        normalized.completedAt = normalized.completedAt ?? run.events.last?.timestamp
        return normalized
    }

    private func activeStartedEvent(in run: WorkflowRunRecord) -> WorkflowRunEvent? {
        let completedRoleIds = Set(run.events.filter { ["role.completed", "role.failed"].contains($0.type) }.compactMap(\.roleId))
        if let startedRole = run.events.last(where: { $0.type == "role.started" && $0.roleId.map { !completedRoleIds.contains($0) } == true }) {
            return startedRole
        }

        let completedTeamIds = Set(run.events.filter { ["team.completed", "team.failed"].contains($0.type) }.compactMap(\.teamId))
        if let startedTeam = run.events.last(where: { $0.type == "team.started" && $0.teamId.map { !completedTeamIds.contains($0) } == true }) {
            return startedTeam
        }

        let completedWorkUnitIds = Set(run.events.filter { ["work_unit.completed", "work_unit.failed"].contains($0.type) }.compactMap(\.workUnitId))
        return run.events.last(where: { $0.type == "work_unit.started" && $0.workUnitId.map { !completedWorkUnitIds.contains($0) } == true })
    }
}

private struct WorkflowRunStatusProjection: Decodable {
    static let activeStatuses: Set<String> = ["running", "reporting", "awaiting_review", "waiting_for_human", "queued", "paused"]

    let runId: String
    let status: String?
    let updatedAt: String?
    let workflowId: String?
    let latestEvent: WorkflowRunEvent?
    let latestEventType: String?
    let latestSummary: String?
    let activeWorkUnitId: String?
    let activeTeamId: String?
    let activeRoleId: String?
    let pendingHumanReview: PendingHumanReviewProjection?

    func asRunRecord() -> WorkflowRunRecord {
        let latestType = latestEvent?.type ?? latestEventType
        let hasActiveWork = activeWorkUnitId != nil || activeTeamId != nil || activeRoleId != nil
        let inferredStatus: String
        if status == "awaiting_review" || latestType == "human_review.requested" {
            inferredStatus = "waiting_for_human"
        } else if let status, !status.isEmpty {
            inferredStatus = status
        } else if hasActiveWork {
            inferredStatus = "running"
        } else if latestType == "workflow.completed" || latestType == "run.completed" {
            inferredStatus = "completed"
        } else if latestType == "workflow.failed" || latestType == "run.failed" {
            inferredStatus = "failed"
        } else {
            inferredStatus = "running"
        }

        return WorkflowRunRecord(
            id: runId,
            workflowId: workflowId ?? latestEvent?.workflowId ?? "unknown.workflow",
            workflowName: workflowId ?? latestEvent?.workflowId ?? "Workflow run",
            status: inferredStatus,
            profileId: "legal-dev",
            startedAt: latestEvent?.timestamp ?? updatedAt ?? runId,
            completedAt: inferredStatus == "completed" ? updatedAt : nil,
            client: DisplayEntity(id: "unknown-client", name: "Unknown client"),
            matter: DisplayEntity(id: "unknown-matter", name: "Unknown matter"),
            stages: latestSummary.map { [WorkflowStageRecord(id: "latest", name: "Latest activity", status: inferredStatus, summary: $0)] } ?? [],
            humanReview: nil,
            outputs: [],
            events: latestEvent.map { [$0] } ?? [],
            entries: []
        )
    }
}

private struct PendingHumanReviewProjection: Decodable {
    let reviewId: String
    let title: String
    let filePath: String?
}

private struct HumanReviewProjection: Decodable {
    let status: String?
    let reviewId: String?
    let title: String?
    let payload: HumanReviewPayload?

    func asHumanReviewRecord(
        fallbackId: String,
        fallbackTitle: String,
        richPayload: AppleHumanReviewPayload?
    ) -> HumanReviewRecord {
        HumanReviewRecord(
            id: reviewId ?? fallbackId,
            status: status == "awaiting_review" ? "requested" : (status ?? "requested"),
            title: title ?? fallbackTitle,
            summary: richPayload?.reviewSummary ?? payload?.summary ?? "Review the workflow output before continuing.",
            segments: payload?.segments.map {
                let detail = richPayload?.matchingItem(for: $0)
                return HumanReviewSegment(
                    id: $0.id,
                    label: $0.title,
                    status: $0.decisionRequired == true ? "decision required" : "optional",
                    decision: nil,
                    summary: detail?.reviewSummary ?? ($0.editable == true ? "Editable" : "Read-only")
                )
            } ?? [
                HumanReviewSegment(
                    id: "review",
                    label: "Review",
                    status: "pending",
                    decision: nil,
                    summary: "Human review is required."
                )
            ]
        )
    }
}

private struct HumanReviewPayload: Decodable {
    let summary: String?
    let segments: [HumanReviewSegmentProjection]
}

private struct HumanReviewSegmentProjection: Decodable {
    let id: String
    let title: String
    let decisionRequired: Bool?
    let editable: Bool?
}

private struct AppleHumanReviewPayload: Decodable {
    let metadata: AppleHumanReviewMetadata?
    let executiveSummary: String?
    let summary: AppleHumanReviewSummary?
    let reviewItems: [AppleHumanReviewItem]
    let allowedDecisions: [String]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let nested = try container.decodeIfPresent(AppleHumanReviewPayload.self, forKey: .reviewPayload) {
            self = nested
            return
        }

        if let packet = try container.decodeIfPresent(AppleReviewPacket.self, forKey: .reviewPacket) {
            metadata = nil
            executiveSummary = "Review each proposed position before the workflow generates its final report."
            summary = nil
            reviewItems = packet.segments.map(AppleHumanReviewItem.init)
            allowedDecisions = nil
            return
        }

        metadata = try container.decodeIfPresent(AppleHumanReviewMetadata.self, forKey: .metadata)
        executiveSummary = try container.decodeIfPresent(String.self, forKey: .executiveSummary)
        summary = try container.decodeIfPresent(AppleHumanReviewSummary.self, forKey: .summary)
        reviewItems = try container.decodeIfPresent([AppleHumanReviewItem].self, forKey: .reviewItems) ?? []
        allowedDecisions = try container.decodeIfPresent([String].self, forKey: .allowedDecisions)
    }

    private enum CodingKeys: String, CodingKey {
        case reviewPayload
        case reviewPacket
        case metadata
        case executiveSummary
        case summary
        case reviewItems
        case allowedDecisions
    }

    var reviewTitle: String {
        if let matterName = metadata?.matterName, !matterName.isEmpty {
            return "Attorney review for \(matterName)"
        }
        return "Attorney review required"
    }

    var reviewSummary: String {
        executiveSummary ?? summary?.executiveSummary ?? "Review the workflow output before continuing."
    }

    func asHumanReviewRecord(runId: String?, reviewId: String? = nil, title: String? = nil) -> HumanReviewRecord {
        HumanReviewRecord(
            id: reviewId ?? "review-\(runId ?? "workflow")",
            status: "requested",
            title: title ?? reviewTitle,
            summary: reviewSummary,
            segments: reviewItems.map { item in
                HumanReviewSegment(
                    id: item.itemId,
                    label: item.title,
                    status: item.status?.lowercased() == "pending review" ? "decision required" : (item.status ?? "decision required"),
                    decision: nil,
                    summary: item.reviewSummary
                )
            }
        )
    }

    func matchingItem(for segment: HumanReviewSegmentProjection) -> AppleHumanReviewItem? {
        let segmentTokens = normalizedTokens(segment.id + " " + segment.title)
        return reviewItems.first { item in
            let itemTokens = normalizedTokens(item.itemId + " " + item.title + " " + item.allRelatedFlags.joined(separator: " "))
            return !segmentTokens.isDisjoint(with: itemTokens)
        }
    }

    private func normalizedTokens(_ value: String) -> Set<String> {
        let stopWords: Set<String> = ["risk", "item", "review", "scope", "and", "the", "for"]
        let normalized = value
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stopWords.contains($0) }
        return Set(normalized)
    }
}

private struct AppleReviewPacket: Decodable {
    let segments: [AppleReviewPacketSegment]
}

private struct AppleReviewPacketSegment: Decodable {
    let segmentId: String
    let title: String
    let description: String
    let riskFlag: String?
    let supportingCitations: [String]?
    let proposedPosition: String?
    let whyItMatters: String?
    let requestedClarification: String?

}

private struct AppleHumanReviewSummary: Decodable {
    let executiveSummary: String
}

private struct AppleHumanReviewMetadata: Decodable {
    let runId: String?
    let matterName: String?
    let jurisdiction: String?
    let clientIndustry: String?
}

private struct AppleHumanReviewItem: Decodable {
    let itemId: String
    let segmentType: String?
    let type: String?
    let title: String
    let riskSeverity: String
    let status: String?
    let description: String
    let sourceDocuments: [String]?
    let citations: [String]?
    let relatedFlags: [String]?
    let reviewerQuestions: [String]?

    init(_ reviewPacketSegment: AppleReviewPacketSegment) {
        itemId = reviewPacketSegment.segmentId
        segmentType = "Attorney review"
        type = nil
        title = reviewPacketSegment.title
        riskSeverity = "Review required"
        status = "decision required"
        description = reviewPacketSegment.description
        sourceDocuments = reviewPacketSegment.supportingCitations
        citations = nil
        relatedFlags = reviewPacketSegment.riskFlag.map { [$0] }
        reviewerQuestions = [
            reviewPacketSegment.proposedPosition.map { "Proposed position: \($0)" },
            reviewPacketSegment.whyItMatters.map { "Why it matters: \($0)" },
            reviewPacketSegment.requestedClarification.map { "Requested clarification: \($0)" }
        ].compactMap { $0 }
    }

    var reviewSummary: String {
        var lines = ["## Issue", description]

        let sources = sourceDocuments ?? citations ?? []
        if !sources.isEmpty {
            lines.append("## Evidence\n" + sources.map { "- `\($0)`" }.joined(separator: "\n"))
        }

        let flags = relatedFlags ?? []
        if !flags.isEmpty {
            lines.append("## Review flags\n" + flags.map { "- \($0)" }.joined(separator: "\n"))
        }

        let questions = reviewerQuestions ?? []
        if !questions.isEmpty {
            lines.append("## Decision context\n" + questions.map { "- \($0)" }.joined(separator: "\n"))
        }

        return lines.joined(separator: "\n\n")
    }

    var allRelatedFlags: [String] {
        self.relatedFlags ?? []
    }
}
