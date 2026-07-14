import SwiftUI

struct HermesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RuntimeProbeView(
            title: "Hermes",
            subtitle: "Local workflow runtime, event source, and skill host.",
            buttonTitle: "Probe Hermes",
            output: appState.hermesOutput,
            action: appState.checkHermes
        )
        .navigationTitle("Hermes")
    }
}
