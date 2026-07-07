import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(selection: $appState.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .navigationTitle("Apple Orchestrator AI")
        } detail: {
            switch appState.selectedSection {
            case .voice:
                VoiceCommandView()
            case .coderEfforts:
                CoderEffortsView()
            case .hermes:
                HermesView()
            case .pi:
                PiView()
            }
        }
        .environment(appState)
    }
}
