import SwiftUI

struct PiView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RuntimeProbeView(
            title: "Pi",
            subtitle: "Developer/admin harness for workflow, prompt, and runtime repair work.",
            buttonTitle: "Probe Pi",
            output: appState.piOutput,
            action: appState.checkPi
        )
        .navigationTitle("Pi")
    }
}
