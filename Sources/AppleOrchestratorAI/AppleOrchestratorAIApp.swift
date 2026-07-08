import SwiftUI

@main
struct AppleOrchestratorAIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .task {
                    await appState.refresh()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Apple Orchestrator AI") {
                    NSApplication.shared.orderFrontStandardAboutPanel()
                }
            }
        }
    }
}
