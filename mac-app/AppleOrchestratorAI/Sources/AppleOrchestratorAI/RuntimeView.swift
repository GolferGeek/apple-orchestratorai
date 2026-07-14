import SwiftUI

struct RuntimeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RuntimeProbeView(
            title: "Runtime",
            subtitle: "Hermes, Pi, shared Ollama on 11435, system Ollama on 11434, and Apple-optimized model tags.",
            buttonTitle: "Probe Runtime",
            output: appState.runtimeOutput,
            action: appState.checkRuntime
        )
        .navigationTitle("Runtime")
    }
}
