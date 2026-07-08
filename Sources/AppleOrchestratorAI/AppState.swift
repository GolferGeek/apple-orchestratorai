import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var readiness: ReadinessReport = .empty
    @Published private(set) var manifest: RuntimeManifest?
    @Published private(set) var workflows: [WorkflowSummary] = []
    @Published private(set) var hermesStatus: HermesAPIStatus?
    @Published private(set) var ollamaStatus: OllamaStatus?
    @Published private(set) var recentRuns: [HermesRunSummary] = []
    @Published var promptText = ""
    @Published var selectedSurface: AppSurface = .status
    @Published var isRefreshing = false
    @Published var isSubmittingPrompt = false

    private let readinessChecker = ReadinessChecker()
    private let manifestLoader = RuntimeManifestLoader()
    private let workflowLoader = WorkflowLoader()
    private let hermesClient = HermesClient()
    private let ollamaClient = OllamaClient()

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        async let readinessTask = readinessChecker.check()
        async let manifestTask = manifestLoader.load()
        async let workflowsTask = workflowLoader.load()
        async let hermesTask = hermesClient.status()
        async let ollamaTask = ollamaClient.status()

        readiness = await readinessTask
        manifest = await manifestTask
        workflows = await workflowsTask
        hermesStatus = await hermesTask
        ollamaStatus = await ollamaTask
    }

    func submitPrompt() async {
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            return
        }

        isSubmittingPrompt = true
        defer { isSubmittingPrompt = false }

        do {
            let response = try await hermesClient.createRun(
                input: prompt,
                instructions: "You are Hermes running inside Apple Orchestrator AI. Return concise, display-ready status."
            )
            promptText = ""
            upsertRun(
                HermesRunSummary(
                    id: response.runID,
                    status: response.status,
                    prompt: prompt,
                    detail: "Submitted to Hermes"
                )
            )

            try? await Task.sleep(for: .seconds(1))
            await refreshRunStatus(response.runID)
        } catch {
            upsertRun(
                HermesRunSummary(
                    id: "failed-\(Date().timeIntervalSince1970)",
                    status: "failed",
                    prompt: prompt,
                    detail: error.localizedDescription
                )
            )
        }
    }

    func refreshRunStatus(_ runID: String) async {
        do {
            let status = try await hermesClient.runStatus(runID: runID)
            upsertRun(
                HermesRunSummary(
                    id: status.runID,
                    status: status.status,
                    prompt: recentRuns.first(where: { $0.id == status.runID })?.prompt ?? "",
                    detail: status.output ?? status.error ?? status.lastEvent ?? "Updated"
                )
            )
        } catch {
            if let existing = recentRuns.first(where: { $0.id == runID }) {
                upsertRun(
                    HermesRunSummary(
                        id: existing.id,
                        status: existing.status,
                        prompt: existing.prompt,
                        detail: error.localizedDescription
                    )
                )
            }
        }
    }

    private func upsertRun(_ run: HermesRunSummary) {
        recentRuns.removeAll { $0.id == run.id }
        recentRuns.insert(run, at: 0)
        recentRuns = Array(recentRuns.prefix(10))
    }
}

enum AppSurface: String, CaseIterable, Identifiable {
    case status = "Status"
    case workflows = "Workflows"
    case runtime = "Runtime"

    var id: String { rawValue }
}
