import AppIntents

struct CurrentEffortIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Current Effort"
    static let description = IntentDescription("Reports the current Apple Orchestrator AI effort.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: EffortIntentReader.currentEffortSummary()))
    }
}

struct EffortStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Effort Status"
    static let description = IntentDescription("Summarizes inbox, current, future, and archived efforts.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: EffortIntentReader.overallStatusSummary()))
    }
}

struct AppleOrchestratorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CurrentEffortIntent(),
            phrases: [
                "What's my current effort in \(.applicationName)",
                "What am I working on in \(.applicationName)"
            ],
            shortTitle: "Current Effort",
            systemImageName: "target"
        )

        AppShortcut(
            intent: EffortStatusIntent(),
            phrases: [
                "How's it going in \(.applicationName)",
                "What's my effort status in \(.applicationName)"
            ],
            shortTitle: "Effort Status",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
