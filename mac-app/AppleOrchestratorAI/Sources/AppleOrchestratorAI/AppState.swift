import AppKit
import Foundation
import Observation
import Darwin

private struct LocalStateSnapshot: Sendable {
    let workflows: [WorkflowCatalogItem]
    let workflowAgents: [String: WorkflowAgentNode]
    let workflowRuns: [WorkflowRunRecord]
}

@Observable
@MainActor
final class AppState {
    var repoRoot: URL?
    var selectedSection: AppSection = .runs
    var selectedWorkflowId = "document-onboarding"
    var statusMessage = "Ready"
    var hermesOutput = ""
    var piOutput = ""
    var runtimeOutput = ""
    var workflows: [WorkflowCatalogItem] = []
    var workflowAgents: [String: WorkflowAgentNode] = [:]
    var workflowRuns: [WorkflowRunRecord] = []
    var liveHermesRunId = ""
    var liveHermesEvents: [WorkflowRunEvent] = []
    var hermesEventStreamStatus = "Not subscribed."
    var activeHermesEventRunIds: [String] = []
    var legalSourceClients: [LegalSourceOption] = []
    var legalSourceMatters: [LegalSourceOption] = []
    var legalSourceDocuments: [LegalSourceOption] = []
    var legalSourceSelection = LegalSourceSelection()
    var legalSourceStatus = "Ask Pi to load clients."
    var isDocumentOnboardingLaunchPresented = false
    var documentOnboardingLocalFiles: [LocalWorkflowFile] = []
    var workflowExplanation: WorkflowExplanation?
    var workflowExplanationStatus = "Ask Hermes to explain a workflow."
    var openRouterAPIKey = ""
    var openRouterModels: [OpenRouterModel] = []
    var selectedBuilderModelId = "qwen/qwen3.6-flash"
    var openRouterStatus = "Add an OpenRouter key to enable the workflow builder."
    var piConsolePrompt = "Explain the purpose of a workflow agent in two concise paragraphs."
    var piConsoleModel = "qwen3.6:27b-mlx"
    var piConsoleAllowsTools = false
    var piConsoleRunId = ""
    var piConsoleEvents: [WorkflowRunEvent] = []
    var piConsoleRawResponse = ""
    var piConsoleStatus = "Ready for a Pi prompt."
    var isPiConsoleRunning = false

    private let workflowCatalogStore = WorkflowCatalogStore()
    private let workflowRunStore = WorkflowRunStore()
    @ObservationIgnored private let hermesRunClient = HermesRunClient()
    @ObservationIgnored private let hermesEventClient = HermesEventClient()
    @ObservationIgnored private let hermesDisplayClient = HermesDisplayClient()
    @ObservationIgnored private let piSourceClient = PiSourceClient()
    @ObservationIgnored private let openRouterClient = OpenRouterClient()
    @ObservationIgnored private var hermesEventTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var localRuntimeFollowTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var piConsoleFollowTask: Task<Void, Never>?

    init() {
        repoRoot = RepositoryLocator.findRepoRoot()
        ApplicationDataLocator.prepareStateRoot()
        openRouterAPIKey = SecureCredentialStore.read(service: "AppleOrchestratorAI", account: "openrouter-api-key") ?? ""
        refreshLocalState()
    }

    func checkHermes() {
        runProbe(script: "scripts/probe-hermes-api.sh", target: .hermes)
    }

    func checkPi() {
        runProbe(script: "scripts/probe-pi.sh", target: .pi)
    }

    func checkRuntime() {
        runProbe(script: "scripts/check-mac-readiness.sh", target: .runtime)
    }

    func refreshLocalState() {
        let repoRoot = repoRoot
        Task {
            let snapshot = await Task.detached(priority: .utility) { [workflowCatalogStore, workflowRunStore] in
                LocalStateSnapshot(
                    workflows: workflowCatalogStore.load(repoRoot: repoRoot),
                    workflowAgents: workflowCatalogStore.loadAgents(repoRoot: repoRoot),
                    workflowRuns: workflowRunStore.load(repoRoot: repoRoot)
                )
            }.value

            workflows = snapshot.workflows
            workflowAgents = snapshot.workflowAgents
            workflowRuns = snapshot.workflowRuns
        }
    }

    func saveOpenRouterAPIKey() {
        let trimmed = openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try SecureCredentialStore.delete(service: "AppleOrchestratorAI", account: "openrouter-api-key")
                openRouterStatus = "OpenRouter key removed from the macOS Keychain."
            } else {
                try SecureCredentialStore.write(trimmed, service: "AppleOrchestratorAI", account: "openrouter-api-key")
                openRouterStatus = "OpenRouter key saved in the macOS Keychain."
            }
        } catch {
            openRouterStatus = "Could not update the Keychain: \(error.localizedDescription)"
        }
    }

    func loadOpenRouterModels() {
        openRouterStatus = "Loading OpenRouter models..."
        let apiKey = openRouterAPIKey
        Task {
            do {
                let models = try await openRouterClient.fetchModels(apiKey: apiKey)
                openRouterModels = models
                if !models.contains(where: { $0.id == selectedBuilderModelId }) {
                    selectedBuilderModelId = recommendedBuilderModels.first(where: { candidate in
                        models.contains(where: { $0.id == candidate })
                    }) ?? models.first?.id ?? ""
                }
                openRouterStatus = "Loaded \(models.count) current OpenRouter models."
            } catch {
                openRouterStatus = "Could not load OpenRouter models: \(error.localizedDescription)"
            }
        }
    }

    var recommendedBuilderModels: [String] {
        [
            "qwen/qwen3.6-flash",
            "deepseek/deepseek-v4-flash",
            "qwen/qwen3.7-plus",
            "google/gemini-3.1-flash-lite",
            "anthropic/claude-sonnet-5",
            "openai/gpt-5.6-terra"
        ]
    }

    func runPiConsolePrompt() {
        guard let repoRoot else {
            piConsoleStatus = "Could not locate the repository."
            return
        }
        let prompt = piConsolePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            piConsoleStatus = "Enter a prompt first."
            return
        }

        let runId = "pi-console-\(Self.runTimestamp())"
        piConsoleRunId = runId
        piConsoleEvents = []
        piConsoleRawResponse = ""
        piConsoleStatus = "Starting Pi..."
        isPiConsoleRunning = true
        piConsoleFollowTask?.cancel()
        piConsoleFollowTask = Task { [weak self] in
            while !Task.isCancelled, let self, self.isPiConsoleRunning, self.piConsoleRunId == runId {
                let events = await Task.detached(priority: .utility) {
                    Self.loadPiConsoleEvents(runId: runId, repoRoot: repoRoot)
                }.value
                self.piConsoleEvents = events
                if Self.piConsoleHasCompleted(events) {
                    self.isPiConsoleRunning = false
                    self.piConsoleStatus = "Pi response complete."
                    break
                }
                try? await Task.sleep(for: .milliseconds(450))
            }
        }

        let model = piConsoleModel
        let allowsTools = piConsoleAllowsTools
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> String in
                var arguments = [
                    "scripts/smoke-pi-rpc-events.py",
                    "--run-id", runId,
                    "--workflow-id", "admin.pi-console",
                    "--stage-id", "pi-console",
                    "--graph-id", "pi-console",
                    "--work-unit-id", "pi-console.prompt",
                    "--skill-id", "pi.console",
                    "--model", model,
                    "--prompt", prompt,
                    "--timeout-seconds", "180",
                    "--stop-on", "runtime.turn.completed,runtime.error",
                    "--no-builtin-tools"
                ]
                if allowsTools {
                    arguments += [
                        "--extension", ".pi/extensions/workflow-tools/index.ts",
                        "--skill", ".pi/skills",
                        "--tools", "workflow_list_source_options,workflow_read_file,workflow_resolve_client_matter,workflow_resolve_documents,workflow_extract_text"
                    ]
                } else {
                    arguments.append("--no-tools")
                }
                do {
                    let command = try Shell.run(
                        "/usr/bin/python3",
                        arguments,
                        cwd: repoRoot,
                        environment: ["APPLE_ORCHESTRATOR_STATE_DIR": ApplicationDataLocator.stateRoot.path]
                    )
                    return command.output.isEmpty ? "Pi finished with exit code \(command.exitCode)." : command.output
                } catch {
                    return error.localizedDescription
                }
            }.value

            let finalState = await Task.detached(priority: .utility) {
                (
                    Self.loadPiConsoleEvents(runId: runId, repoRoot: repoRoot),
                    Self.loadPiConsoleRawResponse(runId: runId, repoRoot: repoRoot)
                )
            }.value
            guard piConsoleRunId == runId else { return }
            piConsoleEvents = finalState.0
            piConsoleRawResponse = finalState.1
            if !Self.piConsoleHasCompleted(finalState.0) {
                piConsoleStatus = result
            }
            isPiConsoleRunning = false
            piConsoleFollowTask?.cancel()
            piConsoleFollowTask = nil
        }
    }

    func clearPiConsole() {
        piConsoleFollowTask?.cancel()
        piConsoleFollowTask = nil
        isPiConsoleRunning = false
        piConsoleRunId = ""
        piConsoleEvents = []
        piConsoleRawResponse = ""
        piConsoleStatus = "Ready for a Pi prompt."
    }

    nonisolated private static func loadPiConsoleEvents(runId: String, repoRoot _: URL) -> [WorkflowRunEvent] {
        let url = ApplicationDataLocator.stateRoot.appending(path: "events/\(runId).jsonl")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return text.split(separator: "\n")
            .compactMap { try? decoder.decode(WorkflowRunEvent.self, from: Data($0.utf8)) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    nonisolated private static func loadPiConsoleRawResponse(runId: String, repoRoot _: URL) -> String {
        let url = ApplicationDataLocator.stateRoot.appending(path: "raw-pi-events/\(runId).jsonl")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text.split(separator: "\n").suffix(20).joined(separator: "\n")
    }

    nonisolated private static func piConsoleHasCompleted(_ events: [WorkflowRunEvent]) -> Bool {
        events.contains { event in
            event.type == "runtime.turn.completed" ||
            event.type == "work_unit.completed" ||
            event.type == "runtime.error"
        }
    }

    func followLocalRuntimeRun(runId: String) {
        let trimmedRunId = runId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRunId.isEmpty else {
            hermesEventStreamStatus = "Enter a run id."
            return
        }

        liveHermesRunId = trimmedRunId
        liveHermesEvents = workflowRuns.first(where: { $0.id == trimmedRunId })?.events ?? []

        if localRuntimeFollowTasks[trimmedRunId] != nil {
            hermesEventStreamStatus = "Already following \(trimmedRunId)."
            return
        }

        hermesEventStreamStatus = "Following \(trimmedRunId)..."
        activeHermesEventRunIds = (activeHermesEventRunIds + [trimmedRunId]).uniqued()

        localRuntimeFollowTasks[trimmedRunId] = Task {
            while !Task.isCancelled {
                let repoRoot = repoRoot
                let latestRuns = await Task.detached(priority: .utility) { [workflowRunStore] in
                    workflowRunStore.load(repoRoot: repoRoot)
                }.value
                workflowRuns = latestRuns

                if let latestRun = latestRuns.first(where: { $0.id == trimmedRunId }) {
                    if liveHermesRunId == trimmedRunId {
                        liveHermesEvents = latestRun.events
                    }

                    hermesEventStreamStatus = "Following \(trimmedRunId): \(latestRun.status)"

                    if Self.isTerminalRunStatus(latestRun.status) {
                        clearLocalRuntimeFollowTask(runId: trimmedRunId)
                        break
                    }
                }

                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func subscribeToHermesRunEvents(runId: String) {
        let trimmedRunId = runId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRunId.isEmpty else {
            hermesEventStreamStatus = "Enter a run id."
            return
        }

        if workflowRuns.contains(where: { $0.id == trimmedRunId }) {
            followLocalRuntimeRun(runId: trimmedRunId)
            return
        }

        liveHermesRunId = trimmedRunId
        liveHermesEvents = []

        if hermesEventTasks[trimmedRunId] != nil {
            hermesEventStreamStatus = "Already streaming \(trimmedRunId)."
            return
        }

        hermesEventStreamStatus = "Subscribing to \(trimmedRunId)..."
        activeHermesEventRunIds = (activeHermesEventRunIds + [trimmedRunId]).uniqued()

        hermesEventTasks[trimmedRunId] = Task { [hermesEventClient] in
            do {
                try await hermesEventClient.streamEvents(runId: trimmedRunId) { event in
                    await MainActor.run {
                        if self.liveHermesRunId == trimmedRunId {
                            self.liveHermesEvents.append(event)
                        }
                        self.workflowRunStore.appendEvent(event, repoRoot: self.repoRoot)
                        self.applyHermesEvent(event)
                        self.hermesEventStreamStatus = "Streaming \(trimmedRunId)"
                    }
                }

                await MainActor.run {
                    self.hermesEventStreamStatus = "Stream ended for \(trimmedRunId)."
                    self.clearHermesEventTask(runId: trimmedRunId)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.hermesEventStreamStatus = "Stream cancelled for \(trimmedRunId)."
                    self.clearHermesEventTask(runId: trimmedRunId)
                }
            } catch {
                await MainActor.run {
                    self.hermesEventStreamStatus = error.localizedDescription
                    self.clearHermesEventTask(runId: trimmedRunId)
                }
            }
        }
    }

    func stopHermesEventStream() {
        let trimmedRunId = liveHermesRunId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRunId.isEmpty, let task = hermesEventTasks[trimmedRunId] {
            task.cancel()
            clearHermesEventTask(runId: trimmedRunId)
            hermesEventStreamStatus = "Stream stopped for \(trimmedRunId)."
            return
        }

        hermesEventTasks.values.forEach { $0.cancel() }
        hermesEventTasks.removeAll()
        localRuntimeFollowTasks.values.forEach { $0.cancel() }
        localRuntimeFollowTasks.removeAll()
        activeHermesEventRunIds = []
        hermesEventStreamStatus = "All streams stopped."
    }

    func approveHumanReview(runId: String, review: HumanReviewRecord) {
        approveHumanReview(
            runId: runId,
            review: review,
            approvedSegmentIds: Set(review.segments.map(\.id))
        )
    }

    func requestHumanReviewChanges(runId: String, review: HumanReviewRecord) {
        requestHumanReviewChanges(runId: runId, review: review, editSuggestions: [:])
    }

    func approveHumanReview(runId: String, review: HumanReviewRecord, approvedSegmentIds: Set<String>) {
        updateHumanReview(
            runId: runId,
            reviewId: review.id,
            decision: "approve",
            approvedSegmentIds: approvedSegmentIds,
            editSuggestions: [:]
        )
        beginFinalReportPhase(runId: runId, reviewId: review.id)
        respond("Review approved. Starting final wrap-up and report.")
        runFinalReportPhase(runId: runId)
    }

    func requestHumanReviewChanges(runId: String, review: HumanReviewRecord, editSuggestions: [String: String]) {
        updateHumanReview(
            runId: runId,
            reviewId: review.id,
            decision: "request_changes",
            approvedSegmentIds: [],
            editSuggestions: editSuggestions
        )
        updateRunStatus(runId: runId, status: "changes_requested", output: nil)
        respond("Review changes requested.")
    }

    func pauseWorkflowRun(runId: String) {
        controlLocalWorkflowRun(runId: runId, action: "pause", status: "paused", eventType: "workflow.paused")
    }

    func resumeWorkflowRun(runId: String) {
        controlLocalWorkflowRun(runId: runId, action: "resume", status: "running", eventType: "workflow.resumed")
        followLocalRuntimeRun(runId: runId)
    }

    func stopWorkflowRun(runId: String) {
        controlLocalWorkflowRun(runId: runId, action: "stop", status: "stopped", eventType: "workflow.stopped")
    }

    func canControlLocalWorkflowRun(runId: String) -> Bool {
        let pidURL = ApplicationDataLocator.stateRoot.appending(path: "runs/\(runId).pid")
        guard let text = try? String(contentsOf: pidURL, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 0 else {
            return false
        }
        return kill(pid, 0) == 0
    }

    func deleteWorkflowRun(runId: String) {
        let pidURL = ApplicationDataLocator.stateRoot.appending(path: "runs/\(runId).pid")
        if let text = try? String(contentsOf: pidURL, encoding: .utf8),
           let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 0 {
            _ = kill(pid, SIGTERM)
        }

        localRuntimeFollowTasks[runId]?.cancel()
        clearLocalRuntimeFollowTask(runId: runId)
        workflowRunStore.deleteRun(runId: runId)
        workflowRuns.removeAll { $0.id == runId }
        if liveHermesRunId == runId {
            liveHermesRunId = ""
            liveHermesEvents = []
        }
        statusMessage = "Deleted workflow run \(runId)."
    }

    func startDocumentOnboardingRun() {
        guard let repoRoot else {
            statusMessage = "Could not locate repository root."
            respond("I could not locate the repository root.")
            return
        }

        let runId = "run-document-onboarding-app-\(Self.runTimestamp())"
        let launchPayloadURL: URL
        let launchPayload: WorkflowLaunchPayload
        do {
            let prepared = try persistDocumentOnboardingLaunchPayload(runId: runId)
            launchPayloadURL = prepared.url
            launchPayload = prepared.payload
        } catch {
            statusMessage = "Could not prepare selected files: \(error.localizedDescription)"
            return
        }

        selectedSection = .runs
        selectedWorkflowId = "document-onboarding"
        isDocumentOnboardingLaunchPresented = false
        statusMessage = "Starting Pi document onboarding..."

        let run = Self.initialDocumentOnboardingRun(
            runId: runId,
            status: "running",
            client: launchPayload.source.client,
            matter: launchPayload.source.matter
        )
        workflowRuns.insert(run, at: 0)
        workflowRunStore.saveRun(run, repoRoot: repoRoot)
        followLocalRuntimeRun(runId: runId)
        respond("Started document onboarding through Pi. This will take several minutes on local models.")

        Task {
            let output = await Task.detached(priority: .userInitiated) {
                do {
                    let result = try Shell.run(
                        "/bin/bash",
                        ["scripts/run-document-onboarding-workflow.sh"],
                        cwd: repoRoot,
                        environment: [
                            "RUN_ID": runId,
                            "MODEL": "qwen3.6:27b-mlx",
                            "LAUNCH_PAYLOAD": launchPayloadURL.path,
                            "APPLE_ORCHESTRATOR_STATE_DIR": ApplicationDataLocator.stateRoot.path
                        ]
                    )
                    return result.output.isEmpty ? "Pi workflow launcher exited with code \(result.exitCode)." : result.output
                } catch {
                    return error.localizedDescription
                }
            }.value

            runtimeOutput = output
            statusMessage = "Document onboarding \(runId) is running in the local Pi runner."
        }
    }

    func runWorkflowTestCase(_ testCase: WorkflowProductTestCase, workflowId: String) {
        guard workflowId == "document-onboarding" else {
            statusMessage = "This workflow does not have a local test-case launcher yet."
            return
        }
        guard testCase.runnable else {
            statusMessage = "\(testCase.name) is documented but not runnable yet."
            return
        }

        legalSourceSelection = LegalSourceSelection()
        statusMessage = "Starting test case: \(testCase.name)"
        startDocumentOnboardingRun()
    }

    func showDocumentOnboardingLaunch() {
        documentOnboardingLocalFiles = []
        isDocumentOnboardingLaunchPresented = true
    }

    func chooseDocumentOnboardingFiles() {
        let panel = NSOpenPanel()
        panel.title = "Add Documents to Document Onboarding"
        panel.message = "Choose one or more documents. You can add more files before starting the workflow."
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add Documents"
        guard panel.runModal() == .OK else { return }

        for url in panel.urls where !documentOnboardingLocalFiles.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            documentOnboardingLocalFiles.append(LocalWorkflowFile(url: url))
        }
    }

    func removeDocumentOnboardingFile(_ file: LocalWorkflowFile) {
        documentOnboardingLocalFiles.removeAll { $0.id == file.id }
    }

    func clearDocumentOnboardingFiles() {
        documentOnboardingLocalFiles = []
    }

    func runDocumentOnboardingDryRun() {
        guard let repoRoot else {
            statusMessage = "Could not locate repository root."
            return
        }

        selectedSection = .runs
        statusMessage = "Running document onboarding dry run..."
        let runId = "run-dry-\(Self.runTimestamp())"

        Task {
            let output = await Task.detached(priority: .userInitiated) {
                do {
                    let result = try Shell.run(
                        "/bin/bash",
                        ["scripts/run-document-onboarding-workflow.sh"],
                        cwd: repoRoot,
                        environment: [
                            "DRY_RUN": "1",
                            "RUN_ID": runId,
                            "APPLE_ORCHESTRATOR_STATE_DIR": ApplicationDataLocator.stateRoot.path
                        ]
                    )
                    return result.output.isEmpty ? "Exit code: \(result.exitCode)" : result.output
                } catch {
                    return error.localizedDescription
                }
            }.value

            runtimeOutput = output
            refreshLocalState()
            let eventCount = workflowRuns.first(where: { $0.id == runId })?.events.count ?? 0
            statusMessage = "Dry run \(runId) finished with \(eventCount) events."
            respond("The document onboarding dry run finished with \(eventCount) events.")
        }
    }

    func plannedProgress(for run: WorkflowRunRecord) -> PlannedRunProgress? {
        guard let agent = workflowAgents[run.workflowId] else {
            return nil
        }

        let stages = agent.children.filter { $0.kind == .phase }.map { stage in
            let workUnitNodes = descendants(of: stage).filter { $0.kind == .workUnit }
            return PlannedStageProgress(
                id: stage.id,
                name: stage.name,
                execution: stage.detail,
                graphId: stage.name,
                subgraphId: stage.children.first(where: { $0.kind == .subphase })?.name,
                workUnits: workUnitNodes.map { workUnit in
                    let events = run.events.filter { event in
                        eventMatchesPlannedWorkUnit(event, workUnit: workUnit, workflowId: run.workflowId)
                    }
                    let status = Self.workUnitStatus(events: events)
                    return PlannedWorkUnitProgress(
                        id: workUnit.id,
                        name: workUnit.name,
                        skillId: descendants(of: workUnit).first(where: { $0.kind == .skill })?.name ?? "workflow skill",
                        optional: !workUnit.required,
                        status: status,
                        lastEventType: events.last?.type
                    )
                }
            )
        }

        let workUnits = stages.flatMap(\.workUnits)
        let latest = run.events.reversed().compactMap { event in
            workUnits.first { workUnit in
                guard let node = findNode(id: workUnit.id, in: agent) else { return false }
                return eventMatchesPlannedWorkUnit(event, workUnit: node, workflowId: run.workflowId)
            }
        }.first

        return PlannedRunProgress(
            stages: stages,
            completedWorkUnitCount: workUnits.filter { $0.status == "completed" }.count,
            totalWorkUnitCount: workUnits.count,
            latestActiveWorkUnit: latest
        )
    }

    private func descendants(of node: WorkflowAgentNode) -> [WorkflowAgentNode] {
        node.children + node.children.flatMap(descendants)
    }

    private func findNode(id: String, in node: WorkflowAgentNode) -> WorkflowAgentNode? {
        if node.id == id { return node }
        for child in node.children {
            if let match = findNode(id: id, in: child) { return match }
        }
        return nil
    }

    private func eventMatchesPlannedWorkUnit(
        _ event: WorkflowRunEvent,
        workUnit: WorkflowAgentNode,
        workflowId: String
    ) -> Bool {
        if workflowId == "document-onboarding" {
            if let legacyMatch = documentOnboardingEventMatch(event, workUnitId: workUnit.id) {
                return legacyMatch
            }
        }

        return event.workUnitId == workUnit.id
            || descendants(of: workUnit).contains(where: { $0.kind == .skill && $0.name == event.skillId })
    }

    /// The first Pi runner uses coarse team work units while the agent document exposes
    /// a more useful, finer-grained plan. Keep this mapping at the UI boundary until the
    /// runner emits the workflow-agent identifiers directly.
    private func documentOnboardingEventMatch(_ event: WorkflowRunEvent, workUnitId: String) -> Bool? {
        let legacyId = event.workUnitId
        switch legacyId {
        case "document_onboarding.source_intake":
            switch workUnitId {
            case "resolve-client-matter-context":
                return event.roleId == "source-lead"
                    || (event.roleId == nil && ["work_unit.started", "team.started"].contains(event.type))
                    || (event.roleId == nil && ["work_unit.completed", "team.completed"].contains(event.type))
            case "resolve-local-file-documents":
                return event.roleId == "intake-worker"
                    || (event.roleId == nil && ["work_unit.completed", "team.completed"].contains(event.type))
            case "extract-document-text":
                return event.roleId == "intake-verifier"
                    || (event.roleId == nil && ["work_unit.completed", "team.completed"].contains(event.type))
            default:
                return false
            }
        case "document_onboarding.metadata":
            return workUnitId == "extract-legal-metadata"
        case "document_onboarding.routing":
            return workUnitId == "route-specialists"
        case "document_onboarding.specialist_review":
            return workUnitId == "run-specialist-lanes"
        case "document_onboarding.synthesis":
            return ["synthesize-findings", "recommend-next-workflow"].contains(workUnitId)
        case "document_onboarding.human_review":
            return workUnitId == "request-attorney-review"
        case "document_onboarding.output":
            return workUnitId == "render-document-onboarding-report"
        default:
            return nil
        }
    }

    func outputPacket(for run: WorkflowRunRecord) -> WorkflowOutputPacket {
        let contracts = workflows.first(where: { $0.id == run.workflowId })?.outputContracts ?? []
        let eventOutputs = run.events.flatMap { $0.outputs ?? [] }
        let items = contracts.map { contract in
            let output = run.outputs.first { $0.id == contract.id } ?? synthesizedOutput(for: contract, in: run)
            return WorkflowOutputPacketItem(
                id: contract.id,
                type: contract.type,
                required: contract.required,
                output: output,
                eventOutput: eventOutputs.last { $0.id == contract.id }
            )
        }
        return WorkflowOutputPacket(items: items)
    }

    private func synthesizedOutput(for contract: WorkflowLaunchOutputContract, in run: WorkflowRunRecord) -> OutputEnvelope? {
        let matchingEntries: [WorkflowRunEntry]
        switch contract.id {
        case "documentsMetadata":
            matchingEntries = run.entries.filter { $0.entryType == "metadata.packet" }
        case "routingDecision":
            matchingEntries = run.entries.filter { $0.entryType == "routing.packet" }
        case "specialistOutputs":
            matchingEntries = run.entries.filter {
                $0.entryType.hasPrefix("specialist.")
                    && !$0.entryType.contains("quality_review")
                    && !$0.entryType.contains("arbitration")
            }
        case "synthesis":
            matchingEntries = run.entries.filter { $0.entryType == "synthesis.packet" }
        case "reviewPayload":
            matchingEntries = run.entries.filter { $0.entryType == "human_review.payload" || $0.entryType == "human_review.requested" }
        default:
            matchingEntries = []
        }

        guard !matchingEntries.isEmpty else { return nil }

        let content = matchingEntries
            .map { entry in
                if matchingEntries.count == 1 {
                    return entry.previewText
                }
                return "## \(entry.entryType)\n\n\(entry.previewText)"
            }
            .joined(separator: "\n\n")

        return OutputEnvelope(
            id: contract.id,
            type: contract.type,
            title: contract.id.humanizedIdentifier,
            content: content
        )
    }

    func explainWorkflow(_ workflow: WorkflowCatalogItem) {
        workflowExplanationStatus = "Asking Hermes to explain \(workflow.name)..."

        Task {
            do {
                workflowExplanation = try await hermesDisplayClient.explainWorkflow(workflow)
                workflowExplanationStatus = "Hermes explained \(workflow.name)."
                respond("Hermes explained \(workflow.name).")
            } catch {
                workflowExplanationStatus = error.localizedDescription
                respond("I could not get the workflow explanation: \(error.localizedDescription)")
            }
        }
    }

    func loadLegalClients() {
        legalSourceStatus = "Asking Pi for clients..."
        Task {
            do {
                legalSourceClients = try await piSourceClient.listLegalSourceOptions(kind: .clients, repoRoot: repoRoot)
                legalSourceStatus = "Pi returned \(legalSourceClients.count) clients."
            } catch {
                legalSourceStatus = error.localizedDescription
            }
        }
    }

    func selectLegalClient(_ client: LegalSourceOption) {
        legalSourceSelection.client = client
        legalSourceSelection.matter = nil
        legalSourceSelection.documents = []
        legalSourceMatters = []
        legalSourceDocuments = []
        legalSourceStatus = "Asking Pi for matters..."

        Task {
            do {
                legalSourceMatters = try await piSourceClient.listLegalSourceOptions(kind: .matters, parentId: client.id, repoRoot: repoRoot)
                legalSourceStatus = "Pi returned \(legalSourceMatters.count) matters for \(client.label)."
            } catch {
                legalSourceStatus = error.localizedDescription
            }
        }
    }

    func selectLegalMatter(_ matter: LegalSourceOption) {
        legalSourceSelection.matter = matter
        legalSourceSelection.documents = []
        legalSourceDocuments = []
        legalSourceStatus = "Asking Pi for documents..."

        Task {
            do {
                legalSourceDocuments = try await piSourceClient.listLegalSourceOptions(kind: .documents, parentId: matter.id, repoRoot: repoRoot)
                legalSourceStatus = "Pi returned \(legalSourceDocuments.count) documents for \(matter.label)."
            } catch {
                legalSourceStatus = error.localizedDescription
            }
        }
    }

    func toggleLegalDocument(_ document: LegalSourceOption) {
        if let index = legalSourceSelection.documents.firstIndex(where: { $0.id == document.id }) {
            legalSourceSelection.documents.remove(at: index)
        } else {
            legalSourceSelection.documents.append(document)
        }
    }

    func openModal(_ modal: ModalSurface) {
        switch modal {
        case .hermes:
            selectedSection = .hermes
        case .pi:
            selectedSection = .pi
        case .runtime:
            selectedSection = .runtime
        case .workflows:
            selectedSection = .workflows
        case .runs:
            selectedSection = .runs
        case .legalSource:
            selectedSection = .legalSource
        }
    }

    private func respond(_ text: String) {
        statusMessage = text
    }

    private enum ProbeTarget {
        case hermes
        case pi
        case runtime
    }

    private func runProbe(script: String, target: ProbeTarget) {
        guard let repoRoot else {
            setProbeOutput("Could not locate repository root.", target: target)
            return
        }

        Task {
            let output = await Task.detached(priority: .userInitiated) {
                do {
                    let result = try Shell.run("/bin/bash", [script], cwd: repoRoot)
                    return result.output.isEmpty ? "Exit code: \(result.exitCode)" : result.output
                } catch {
                    return error.localizedDescription
                }
            }.value

            setProbeOutput(output, target: target)
        }
    }

    private func setProbeOutput(_ output: String, target: ProbeTarget) {
        switch target {
        case .hermes:
            hermesOutput = output
        case .pi:
            piOutput = output
        case .runtime:
            runtimeOutput = output
        }
    }

    private func applyHermesEvent(_ event: WorkflowRunEvent) {
        guard let index = workflowRuns.firstIndex(where: { $0.id == event.runId }) else {
            return
        }

        workflowRuns[index].events.append(event)

        switch event.type {
        case "run.completed", "completed":
            workflowRuns[index].status = "completed"
            workflowRuns[index].completedAt = Self.isoTimestamp()
            if workflowRuns[index].outputs.isEmpty {
                workflowRuns[index].outputs = [
                    OutputEnvelope(
                        id: "output-summary",
                        type: "markdown",
                        title: "Run Completed",
                        content: "Hermes reported the run completed."
                    )
                ]
            }
        case "run.failed", "failed":
            workflowRuns[index].status = "failed"
            workflowRuns[index].completedAt = Self.isoTimestamp()
        case "approval.request":
            workflowRuns[index].status = "waiting_for_human"
            workflowRuns[index].humanReview = HumanReviewRecord(
                id: event.reviewId ?? "approval-\(event.runId)",
                status: "requested",
                title: "Human Approval Requested",
                summary: "Hermes requested human approval.",
                segments: [
                    HumanReviewSegment(
                        id: "approval",
                        label: "Approval",
                        status: "pending",
                        decision: nil,
                        summary: "Review the Hermes approval request."
                    )
                ]
            )
        default:
            if event.type.hasPrefix("run.") || event.type.hasPrefix("message.") {
                workflowRuns[index].status = "running"
            }
        }

        workflowRunStore.saveRun(workflowRuns[index], repoRoot: repoRoot)
    }

    private func clearHermesEventTask(runId: String) {
        hermesEventTasks[runId] = nil
        activeHermesEventRunIds.removeAll { $0 == runId }
    }

    private func clearLocalRuntimeFollowTask(runId: String) {
        localRuntimeFollowTasks[runId] = nil
        activeHermesEventRunIds.removeAll { $0 == runId }
    }

    private func autoFollowActiveLocalRuns() {
        for run in workflowRuns where Self.shouldAutoFollow(run.status) {
            followLocalRuntimeRun(runId: run.id)
        }
    }

    private func controlLocalWorkflowRun(runId: String, action: String, status: String, eventType: String) {
        guard let repoRoot else {
            statusMessage = "Could not locate the local workflow runtime."
            return
        }

        statusMessage = "\(action.capitalized) requested for \(runId)..."
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                try? Shell.run(
                    "/bin/bash",
                    ["scripts/control-workflow-run.sh", action, runId],
                    cwd: repoRoot,
                    environment: ["APPLE_ORCHESTRATOR_STATE_DIR": ApplicationDataLocator.stateRoot.path]
                )
            }.value

            guard let result, result.exitCode == 0 else {
                let detail = result?.output.trimmingCharacters(in: .whitespacesAndNewlines)
                statusMessage = detail?.isEmpty == false ? detail! : "Could not \(action) \(runId)."
                return
            }

            recordLocalWorkflowControl(runId: runId, status: status, eventType: eventType, summary: result.output)
            statusMessage = "\(action.capitalized) requested for \(runId)."
        }
    }

    private func recordLocalWorkflowControl(runId: String, status: String, eventType: String, summary: String) {
        guard let index = workflowRuns.firstIndex(where: { $0.id == runId }) else { return }
        workflowRuns[index].status = status
        workflowRuns[index].completedAt = status == "stopped" ? Self.isoTimestamp() : nil
        let event = WorkflowRunEvent(
            timestamp: Self.isoTimestamp(),
            type: eventType,
            runId: runId,
            workflowId: workflowRuns[index].workflowId,
            status: status,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            rawHermesRunId: runId
        )
        workflowRuns[index].events.append(event)
        workflowRunStore.appendEvent(event, repoRoot: repoRoot)
        workflowRunStore.saveRun(workflowRuns[index], repoRoot: repoRoot)
    }

    private func transitionWorkflowRun(
        runId: String,
        actionVerb: String,
        successMessage: String,
        operation: @escaping () async throws -> HermesRunStatusResponse
    ) {
        statusMessage = "\(actionVerb) \(runId)..."

        Task {
            do {
                let response = try await operation()
                updateRunStatus(runId: runId, status: response.status, output: response.output)
                respond(successMessage)
            } catch {
                statusMessage = error.localizedDescription
                respond("Hermes could not update that run: \(error.localizedDescription)")
            }
        }
    }

    private func submitHumanReviewDecision(runId: String, review: HumanReviewRecord, decision: String, note: String) {
        statusMessage = "Sending \(decision) to Hermes..."

        Task {
            do {
                let response = try await hermesRunClient.submitApproval(runId: runId, review: review, decision: decision, note: note)
                updateHumanReview(runId: runId, reviewId: review.id, decision: decision)
                updateRunStatus(runId: runId, status: response.status, output: response.output)
                respond("I sent the review decision to Hermes.")
            } catch {
                statusMessage = error.localizedDescription
                respond("I could not send the review decision: \(error.localizedDescription)")
            }
        }
    }

    private func updateHumanReview(
        runId: String,
        reviewId: String,
        decision: String,
        approvedSegmentIds: Set<String>? = nil,
        editSuggestions: [String: String] = [:]
    ) {
        guard let index = workflowRuns.firstIndex(where: { $0.id == runId }), let review = workflowRuns[index].humanReview else {
            return
        }

        let segmentStatus = decision == "approve" ? "approved" : "changes_requested"
        workflowRuns[index].humanReview = HumanReviewRecord(
            id: review.id,
            status: segmentStatus,
            title: review.title,
            summary: review.summary,
            segments: review.segments.map {
                let suggestion = editSuggestions[$0.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
                let isApproved = approvedSegmentIds?.contains($0.id) == true
                let nextStatus = suggestion?.isEmpty == false ? "changes_requested" : (isApproved || decision == "approve" ? "approved" : segmentStatus)
                let nextDecision = suggestion?.isEmpty == false ? "request_changes" : (isApproved || decision == "approve" ? "approve" : decision)
                let nextSummary = suggestion?.isEmpty == false ? "\($0.summary)\n\nSuggested edit:\n\(suggestion ?? "")" : $0.summary
                return HumanReviewSegment(
                    id: $0.id,
                    label: $0.label,
                    status: nextStatus,
                    decision: nextDecision,
                    summary: nextSummary
                )
            }
        )

        let event = WorkflowRunEvent(
            timestamp: Self.isoTimestamp(),
            type: decision == "approve" ? "human_review.completed" : "human_review.changes_requested",
            runId: runId,
            reviewId: reviewId,
            status: segmentStatus,
            summary: decision == "approve" ? "Human review approved." : "Human review changes requested.",
            rawHermesRunId: runId
        )
        workflowRuns[index].events.append(event)
        workflowRunStore.appendEvent(event, repoRoot: repoRoot)
        workflowRunStore.saveRun(workflowRuns[index], repoRoot: repoRoot)
    }

    private func beginFinalReportPhase(runId: String, reviewId: String) {
        guard let index = workflowRuns.firstIndex(where: { $0.id == runId }) else {
            return
        }

        workflowRuns[index].status = "reporting"
        workflowRuns[index].completedAt = nil

        let reportStage = WorkflowStageRecord(
            id: "report",
            name: "Wrap-up and report",
            status: "running",
            summary: "Human review approved. Preparing the final output packet and report."
        )

        if let stageIndex = workflowRuns[index].stages.firstIndex(where: { $0.id == reportStage.id }) {
            workflowRuns[index].stages[stageIndex] = reportStage
        } else {
            workflowRuns[index].stages.append(reportStage)
        }

        let event = WorkflowRunEvent(
            timestamp: Self.isoTimestamp(),
            type: "work_unit.started",
            runId: runId,
            workflowId: workflowRuns[index].workflowId,
            stageId: "report",
            graphId: "synthesis_review_and_report",
            subgraphId: "report_generation",
            workUnitId: "document_onboarding.output",
            teamId: "output-team",
            reviewId: reviewId,
            status: "running",
            summary: "Final wrap-up and report generation started after human review approval.",
            rawHermesRunId: runId
        )

        workflowRuns[index].events.append(event)
        workflowRunStore.appendEvent(event, repoRoot: repoRoot)
        workflowRunStore.saveRun(workflowRuns[index], repoRoot: repoRoot)
    }

    private func runFinalReportPhase(runId: String) {
        guard let repoRoot else {
            statusMessage = "Could not locate repository root for final report."
            return
        }

        Task {
            let output = await Task.detached(priority: .userInitiated) {
                do {
                    let result = try Shell.run(
                        "/bin/bash",
                        ["scripts/smoke-document-onboarding-output-team.sh"],
                        cwd: repoRoot,
                        environment: [
                            "RUN_ID": runId,
                            "MODEL": "qwen3.6:27b-mlx",
                            "APPLE_ORCHESTRATOR_STATE_DIR": ApplicationDataLocator.stateRoot.path
                        ]
                    )

                    if result.exitCode == 0 {
                        return result.output.isEmpty ? "Final report completed." : result.output
                    }

                    return result.output.isEmpty ? "Final report failed with exit code \(result.exitCode)." : result.output
                } catch {
                    return error.localizedDescription
                }
            }.value

            runtimeOutput = output
            refreshLocalState()

            if output.contains("artifact:") && !output.lowercased().contains("missing artifact") {
                statusMessage = "Final report generated for \(runId)."
            } else {
                statusMessage = "Final report phase finished; check Runtime for details."
            }
        }
    }

    private func updateRunStatus(runId: String, status: String, output: String?) {
        guard let index = workflowRuns.firstIndex(where: { $0.id == runId }) else {
            return
        }

        workflowRuns[index].status = status == "started" ? "running" : status
        if ["completed", "failed", "cancelled", "stopped"].contains(status) {
            workflowRuns[index].completedAt = Self.isoTimestamp()
        }

        if let output, !output.isEmpty {
            workflowRuns[index].outputs = [
                OutputEnvelope(
                    id: "hermes-output",
                    type: "markdown",
                    title: "Hermes Output",
                    content: output
                )
            ]
        }

        workflowRunStore.saveRun(workflowRuns[index], repoRoot: repoRoot)
    }

    private func documentOnboardingLaunchInput() -> String {
        let payload = documentOnboardingLaunchPayload()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payloadText: String
        if let data = try? encoder.encode(payload), let text = String(data: data, encoding: .utf8) {
            payloadText = text
        } else {
            payloadText = "{}"
        }

        return """
        Run the Apple Orchestrator AI workflow using this typed launch payload.
        Treat the payload as the source of truth. Resolve source references through Hermes skills or MCP, not through the frontend.
        Return concise progress and final output through normal Hermes run events. Do not call external model providers.
        \(payloadText)
        """
    }

    private func persistDocumentOnboardingLaunchPayload(runId: String) throws -> (url: URL, payload: WorkflowLaunchPayload) {
        let stagedFiles = try stageSelectedLocalFiles(runId: runId)
        let payload = documentOnboardingLaunchPayload(stagedFiles: stagedFiles)
        let directory = ApplicationDataLocator.stateRoot.appending(path: "launches", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "\(runId).launch.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: fileURL, options: .atomic)
        return (fileURL, payload)
    }

    private func stageSelectedLocalFiles(runId: String) throws -> [URL] {
        guard !documentOnboardingLocalFiles.isEmpty else { return [] }
        let directory = ApplicationDataLocator.stateRoot
            .appending(path: "documents", directoryHint: .isDirectory)
            .appending(path: runId, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return try documentOnboardingLocalFiles.enumerated().map { index, file in
            let didAccess = file.url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { file.url.stopAccessingSecurityScopedResource() }
            }
            let destination = directory.appending(path: "\(index + 1)-\(file.name)")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: file.url, to: destination)
            return destination
        }
    }

    private func documentOnboardingLaunchPayload(stagedFiles: [URL] = []) -> WorkflowLaunchPayload {
        let outputContracts = workflows.first(where: { $0.id == "document-onboarding" })?.outputContracts ?? []
        if !stagedFiles.isEmpty {
            return Self.documentOnboardingLaunchPayload(
                launchMode: "local-files",
                classification: "user-selected-local-files",
                resolver: "shared.local-file-resolve-documents.v0",
                client: DisplayEntity(id: "local-client", name: "Local document set"),
                matter: DisplayEntity(id: "local-matter", name: "Unassigned local matter"),
                documentIds: stagedFiles.enumerated().map { "local-document-\($0.offset + 1)" },
                documentLabels: stagedFiles.map(\.lastPathComponent),
                baseDirectory: stagedFiles.first?.deletingLastPathComponent().path,
                filePaths: stagedFiles.map(\.path),
                sourceUris: stagedFiles.map { $0.absoluteString },
                outputContracts: outputContracts
            )
        }
        if let client = legalSourceSelection.client, let matter = legalSourceSelection.matter {
            return Self.documentOnboardingLaunchPayload(
                launchMode: "legal-source-picker",
                classification: "client-confidential",
                resolver: "legal.shared.list-legal-source-options.v0",
                client: DisplayEntity(id: client.id, name: client.label),
                matter: DisplayEntity(id: matter.id, name: matter.label),
                documentIds: legalSourceSelection.documents.map(\.id),
                documentLabels: legalSourceSelection.documents.map(\.label),
                baseDirectory: nil,
                filePaths: [],
                sourceUris: [],
                outputContracts: outputContracts
            )
        }

        return Self.documentOnboardingLaunchPayload(
            launchMode: "fixture",
            classification: "demo-or-public",
            resolver: "shared.local-file-resolve-documents.v0",
            client: DisplayEntity(id: "client-acme-robotics", name: "Acme Robotics LLC"),
            matter: DisplayEntity(id: "matter-vendor-renewal-2026", name: "Vendor Agreement Renewal"),
            documentIds: [],
            documentLabels: ["engagement-letter.md", "vendor-renewal-summary.md"],
            baseDirectory: "test-fixtures/legal/document-onboarding/acme-renewal",
            filePaths: ["engagement-letter.md", "vendor-renewal-summary.md"],
            sourceUris: [
                "file://test-fixtures/legal/document-onboarding/acme-renewal/engagement-letter.md",
                "file://test-fixtures/legal/document-onboarding/acme-renewal/vendor-renewal-summary.md"
            ],
            outputContracts: outputContracts
        )
    }

    private static func documentOnboardingLaunchPayload(
        launchMode: String,
        classification: String,
        resolver: String,
        client: DisplayEntity,
        matter: DisplayEntity,
        documentIds: [String],
        documentLabels: [String],
        baseDirectory: String?,
        filePaths: [String],
        sourceUris: [String],
        outputContracts: [WorkflowLaunchOutputContract]
    ) -> WorkflowLaunchPayload {
        WorkflowLaunchPayload(
            schemaVersion: "workflow.launch.v0",
            kind: "workflow.launch",
            workflowId: "document-onboarding",
            profileId: "legal-dev",
            launchMode: launchMode,
            classification: classification,
            modelPolicy: WorkflowLaunchModelPolicy(
                defaultRoute: "local",
                sovereignty: "local-only",
                defaultLocalModel: "qwen3.6:35b-a3b-nvfp4",
                allowedRoutes: ["local"],
                fallbackBehavior: "fail-with-explanation"
            ),
            source: WorkflowLaunchSource(
                resolver: resolver,
                client: client,
                matter: matter,
                documentIds: documentIds,
                documentLabels: documentLabels,
                baseDirectory: baseDirectory,
                filePaths: filePaths,
                sourceUris: sourceUris
            ),
            outputContracts: outputContracts,
            instructions: [
                "Resolve client, matter, and document references inside Hermes.",
                "Do not let the frontend access source stores directly.",
                "Emit workflow-event.v0 compatible progress events.",
                "Pause for human review when the workflow asks for it.",
                "Do not use external model providers for local-only workflows."
            ]
        )
    }

    private static func initialDocumentOnboardingRun(
        runId: String,
        status: String,
        client: DisplayEntity = DisplayEntity(id: "client-acme-robotics", name: "Acme Robotics LLC"),
        matter: DisplayEntity = DisplayEntity(id: "matter-vendor-renewal-2026", name: "Vendor Agreement Renewal")
    ) -> WorkflowRunRecord {
        WorkflowRunRecord(
            id: runId,
            workflowId: "document-onboarding",
            workflowName: "Document Onboarding",
            status: status == "started" ? "running" : status,
            profileId: "legal-dev",
            startedAt: isoTimestamp(),
            completedAt: nil,
            client: client,
            matter: matter,
            stages: ["metadata", "classify", "specialists", "synthesis", "hitl_review", "report"].map {
                WorkflowStageRecord(
                    id: $0,
                    name: $0.replacingOccurrences(of: "_", with: " ").capitalized,
                    status: "defined",
                    summary: "Waiting for Pi workflow events."
                )
            },
            humanReview: nil,
            outputs: [],
            events: []
        )
    }

    private static func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func workUnitStatus(events: [WorkflowRunEvent]) -> String {
        let lifecycleTypes: Set<String> = [
            "work_unit.completed", "stage.completed", "team.completed", "role.completed",
            "work_unit.started", "stage.started", "team.started", "role.started"
        ]
        guard let latest = events.last(where: { lifecycleTypes.contains($0.type) }) else {
            return "defined"
        }
        if ["work_unit.completed", "stage.completed", "team.completed", "role.completed"].contains(latest.type) {
            return "completed"
        }
        return "running"
    }

    private static func shouldAutoFollow(_ status: String) -> Bool {
        ["running", "awaiting_review", "waiting_for_human", "queued"].contains(status)
    }

    private static func isTerminalRunStatus(_ status: String) -> Bool {
        ["completed", "failed", "cancelled", "stopped", "interrupted"].contains(status)
    }

    nonisolated private static func runTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }

}

private extension String {
    var humanizedIdentifier: String {
        replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            .joined(separator: " ")
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
