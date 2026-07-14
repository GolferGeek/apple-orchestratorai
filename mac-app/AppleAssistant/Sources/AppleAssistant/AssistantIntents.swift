import AppIntents

struct AssistantCurrentEffortIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Current Coding Effort"
    static let description = IntentDescription("Reports the current coding effort from Apple Assistant.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: AssistantIntentReader.currentCoderEffortSummary()))
    }
}

struct AssistantProfileStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Assistant Profile Status"
    static let description = IntentDescription("Summarizes the Apple Assistant profile surfaces.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: AssistantIntentReader.profileStatusSummary()))
    }
}

struct AppleAssistantShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AssistantCurrentEffortIntent(),
            phrases: [
                "What's my current coding effort in \(.applicationName)",
                "What is Coder working on in \(.applicationName)"
            ],
            shortTitle: "Current Coding Effort",
            systemImageName: "hammer"
        )

        AppShortcut(
            intent: AssistantProfileStatusIntent(),
            phrases: [
                "How's it going in \(.applicationName)",
                "What's my assistant status in \(.applicationName)"
            ],
            shortTitle: "Assistant Status",
            systemImageName: "person.crop.circle"
        )
    }
}
