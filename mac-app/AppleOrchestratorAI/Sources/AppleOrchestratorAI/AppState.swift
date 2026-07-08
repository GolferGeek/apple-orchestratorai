import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class AppState {
    var repoRoot: URL?
    var selectedSection: AppSection = .voice
    var activeModal: ModalSurface?
    var recentModalSurfaces: [ModalSurface] = []
    var statusMessage = "Ready"
    var hermesOutput = ""
    var piOutput = ""
    var runtimeOutput = ""
    var workflows: [WorkflowCatalogItem] = []
    var workflowRuns: [WorkflowRunRecord] = []
    var liveHermesRunId = ""
    var liveHermesEvents: [WorkflowRunEvent] = []
    var hermesEventStreamStatus = "Not subscribed."
    var legalSourceClients: [LegalSourceOption] = []
    var legalSourceMatters: [LegalSourceOption] = []
    var legalSourceDocuments: [LegalSourceOption] = []
    var legalSourceSelection = LegalSourceSelection()
    var legalSourceStatus = "Ask Hermes to load clients."
    var workflowExplanation: WorkflowExplanation?
    var workflowExplanationStatus = "Ask Hermes to explain a workflow."
    var voiceCommand = ""
    var voicePrompt = "Tell me what workflow you want to build or run. Try: show workflows, show runs, check Hermes, check Pi, or help."
    var voiceLines: [String] = [
        "App: Tell me what you want to do."
    ]
    var isListening = false
    var speechStatus = "Microphone idle."

    private let speechSynthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SpeechCommandRecognizer()
    private let workflowCatalogStore = WorkflowCatalogStore()
    private let workflowRunStore = WorkflowRunStore()
    @ObservationIgnored private let hermesRunClient = HermesRunClient()
    @ObservationIgnored private let hermesEventClient = HermesEventClient()
    @ObservationIgnored private let hermesDisplayClient = HermesDisplayClient()
    @ObservationIgnored private var hermesEventTask: Task<Void, Never>?

    init() {
        repoRoot = RepositoryLocator.findRepoRoot()
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
        workflows = workflowCatalogStore.load(repoRoot: repoRoot)
        workflowRuns = workflowRunStore.load(repoRoot: repoRoot)
    }

    func subscribeToHermesRunEvents(runId: String) {
        let trimmedRunId = runId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRunId.isEmpty else {
            hermesEventStreamStatus = "Enter a Hermes run id."
            return
        }

        hermesEventTask?.cancel()
        liveHermesRunId = trimmedRunId
        liveHermesEvents = []
        hermesEventStreamStatus = "Subscribing to \(trimmedRunId)..."

        hermesEventTask = Task { [hermesEventClient] in
            do {
                try await hermesEventClient.streamEvents(runId: trimmedRunId) { event in
                    await MainActor.run {
                        self.liveHermesEvents.append(event)
                        self.workflowRunStore.appendEvent(event, repoRoot: self.repoRoot)
                        self.applyHermesEvent(event)
                        self.hermesEventStreamStatus = "Streaming \(trimmedRunId)"
                    }
                }

                await MainActor.run {
                    self.hermesEventStreamStatus = "Stream ended for \(trimmedRunId)."
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.hermesEventStreamStatus = "Stream cancelled."
                }
            } catch {
                await MainActor.run {
                    self.hermesEventStreamStatus = error.localizedDescription
                }
            }
        }
    }

    func stopHermesEventStream() {
        hermesEventTask?.cancel()
        hermesEventTask = nil
        hermesEventStreamStatus = "Stream stopped."
    }

    func approveHumanReview(runId: String, review: HumanReviewRecord) {
        submitHumanReviewDecision(runId: runId, review: review, decision: "approve", note: "Approved from Apple Orchestrator AI.")
    }

    func requestHumanReviewChanges(runId: String, review: HumanReviewRecord) {
        submitHumanReviewDecision(runId: runId, review: review, decision: "request_changes", note: "Changes requested from Apple Orchestrator AI.")
    }

    func stopWorkflowRun(runId: String) {
        statusMessage = "Stopping \(runId)..."

        Task {
            do {
                let response = try await hermesRunClient.stopRun(runId: runId)
                updateRunStatus(runId: runId, status: response.status, output: response.output)
                respond("I asked Hermes to stop the run.")
            } catch {
                statusMessage = error.localizedDescription
                respond("I could not stop that run: \(error.localizedDescription)")
            }
        }
    }

    func startDocumentOnboardingRun() {
        openModal(.runs)
        statusMessage = "Starting document onboarding..."

        Task {
            do {
                let response = try await hermesRunClient.startRun(
                    input: documentOnboardingPrompt(),
                    model: "qwen3.6:35b-a3b-nvfp4",
                    sessionId: "apple-orchestratorai-document-onboarding"
                )

                let run = Self.initialDocumentOnboardingRun(runId: response.runId, status: response.status)
                workflowRuns.insert(run, at: 0)
                workflowRunStore.saveRun(run, repoRoot: repoRoot)
                statusMessage = "Started \(response.runId)"
                respond("Started document onboarding. I am subscribing to events.")
                subscribeToHermesRunEvents(runId: response.runId)
            } catch {
                statusMessage = error.localizedDescription
                respond("I could not start document onboarding: \(error.localizedDescription)")
            }
        }
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
        legalSourceStatus = "Asking Hermes for clients..."
        Task {
            do {
                legalSourceClients = try await hermesDisplayClient.listLegalSourceOptions(kind: .clients)
                legalSourceStatus = "Hermes returned \(legalSourceClients.count) clients."
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
        legalSourceStatus = "Asking Hermes for matters..."

        Task {
            do {
                legalSourceMatters = try await hermesDisplayClient.listLegalSourceOptions(kind: .matters, parentId: client.id)
                legalSourceStatus = "Hermes returned \(legalSourceMatters.count) matters for \(client.label)."
            } catch {
                legalSourceStatus = error.localizedDescription
            }
        }
    }

    func selectLegalMatter(_ matter: LegalSourceOption) {
        legalSourceSelection.matter = matter
        legalSourceSelection.documents = []
        legalSourceDocuments = []
        legalSourceStatus = "Asking Hermes for documents..."

        Task {
            do {
                legalSourceDocuments = try await hermesDisplayClient.listLegalSourceOptions(kind: .documents, parentId: matter.id)
                legalSourceStatus = "Hermes returned \(legalSourceDocuments.count) documents for \(matter.label)."
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

    func submitVoiceCommand() {
        let command = voiceCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            speak("Tell me what you want to do.")
            return
        }

        voiceLines.append("You: \(command)")
        voiceCommand = ""
        handleVoiceCommand(command)
    }

    func speakPrompt() {
        speak(voicePrompt)
    }

    func runQuickCommand(_ command: String) {
        voiceCommand = command
        submitVoiceCommand()
    }

    func toggleListening() {
        if isListening {
            speechRecognizer.stop()
            isListening = false
            speechStatus = "Microphone idle."
            return
        }

        Task {
            await speechRecognizer.start { [weak self] transcript, isFinal in
                guard let self else { return }
                self.voiceCommand = transcript
                if isFinal {
                    self.submitVoiceCommand()
                    self.isListening = false
                    self.speechStatus = "Microphone idle."
                }
            } onStatus: { [weak self] status in
                guard let self else { return }
                self.speechStatus = status
                self.isListening = self.speechRecognizer.isListening
            }
            isListening = speechRecognizer.isListening
        }
    }

    private func handleVoiceCommand(_ command: String) {
        let normalized = command.lowercased()

        if normalized.contains("help") {
            respond("You can say show workflows, show runs, check Hermes, check Pi, check runtime, open legal workflows, or go home.")
        } else if normalized.contains("show workflows") || normalized.contains("list workflows") || normalized.contains("workflow catalog") {
            refreshLocalState()
            openModal(.workflows)
            respond("Opening workflows.")
        } else if normalized.contains("run document onboarding") || normalized.contains("start document onboarding") {
            startDocumentOnboardingRun()
        } else if normalized.contains("legal source") || normalized.contains("pick client") || normalized.contains("select client") || normalized.contains("client matter") {
            openModal(.legalSource)
            loadLegalClients()
            respond("Opening the legal source picker. Hermes will provide the client and matter lists.")
        } else if normalized.contains("show runs") || normalized.contains("current run") || normalized.contains("workflow runs") || normalized.contains("show outputs") || normalized.contains("events") {
            refreshLocalState()
            openModal(.runs)
            respond("Opening runs and outputs.")
        } else if normalized.contains("check hermes") || normalized.contains("probe hermes") {
            openModal(.hermes)
            checkHermes()
            respond("Checking Hermes.")
        } else if normalized.contains("hermes") {
            openModal(.hermes)
            respond("Opening Hermes.")
        } else if normalized.contains("check pi") || normalized.contains("probe pi") {
            openModal(.pi)
            checkPi()
            respond("Checking Pi.")
        } else if normalized.contains("check runtime") || normalized.contains("check ollama") || normalized.contains("probe runtime") || normalized.contains("probe ollama") {
            openModal(.runtime)
            checkRuntime()
            respond("Checking runtime.")
        } else if normalized.contains("runtime") || normalized.contains("ollama") {
            openModal(.runtime)
            respond("Opening runtime.")
        } else if normalized == "pi" || normalized.contains("open pi") || normalized.contains("show pi") {
            openModal(.pi)
            respond("Opening Pi.")
        } else if normalized.contains("legal") || normalized.contains("workflow") {
            refreshLocalState()
            openModal(.workflows)
            respond("Opening legal workflows.")
        } else if normalized.contains("home") || normalized.contains("voice") {
            selectedSection = .voice
            respond("Back to voice.")
        } else {
            respond("I did not recognize that command yet. Try show workflows, check Hermes, or check Pi.")
        }
    }

    func openModal(_ modal: ModalSurface) {
        if !recentModalSurfaces.contains(where: { $0 == modal }) {
            recentModalSurfaces.append(modal)
        }
        activeModal = modal
    }

    private func respond(_ text: String) {
        voiceLines.append("App: \(text)")
        speak(text)
    }

    private func speak(_ text: String) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
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

    private func updateHumanReview(runId: String, reviewId: String, decision: String) {
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
                HumanReviewSegment(
                    id: $0.id,
                    label: $0.label,
                    status: segmentStatus,
                    decision: decision,
                    summary: $0.summary
                )
            }
        )

        let event = WorkflowRunEvent(
            timestamp: Self.isoTimestamp(),
            type: "approval.responded",
            runId: runId,
            reviewId: reviewId,
            rawHermesRunId: runId
        )
        workflowRuns[index].events.append(event)
        workflowRunStore.appendEvent(event, repoRoot: repoRoot)
        workflowRunStore.saveRun(workflowRuns[index], repoRoot: repoRoot)
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

    private func documentOnboardingPrompt() -> String {
        if let client = legalSourceSelection.client, let matter = legalSourceSelection.matter {
            let documentIds = legalSourceSelection.documents.map(\.id).joined(separator: ", ")
            return """
            Run the Apple Orchestrator AI document-onboarding workflow in local-only mode.
            Resolve selected legal source references through Hermes/MCP, not through the frontend.
            Client id: \(client.id)
            Matter id: \(matter.id)
            Document ids: \(documentIds.isEmpty ? "all selected matter documents" : documentIds)
            Return concise progress and final output. Do not call external model providers.
            """
        }

        return """
        Run the Apple Orchestrator AI document-onboarding workflow in local-only demo mode.
        Use the Acme Robotics LLC / Vendor Agreement Renewal fixture.
        Return concise progress and final output. Do not call external model providers.
        """
    }

    private static func initialDocumentOnboardingRun(runId: String, status: String) -> WorkflowRunRecord {
        WorkflowRunRecord(
            id: runId,
            workflowId: "document-onboarding",
            workflowName: "Document Onboarding",
            status: status == "started" ? "running" : status,
            profileId: "legal-dev",
            startedAt: isoTimestamp(),
            completedAt: nil,
            client: DisplayEntity(id: "client-acme-robotics", name: "Acme Robotics LLC"),
            matter: DisplayEntity(id: "matter-vendor-renewal-2026", name: "Vendor Agreement Renewal"),
            stages: ["metadata", "classify", "specialists", "synthesis", "hitl_review", "report"].map {
                WorkflowStageRecord(
                    id: $0,
                    name: $0.replacingOccurrences(of: "_", with: " ").capitalized,
                    status: "defined",
                    summary: "Waiting for Hermes events."
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

}
