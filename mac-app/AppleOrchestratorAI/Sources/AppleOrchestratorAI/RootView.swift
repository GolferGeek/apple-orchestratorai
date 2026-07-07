import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink {
                    CoderEffortsView()
                } label: {
                    Label("Coder Efforts", systemImage: "hammer")
                }

                NavigationLink {
                    HermesView()
                } label: {
                    Label("Hermes", systemImage: "bolt.horizontal")
                }

                NavigationLink {
                    PiView()
                } label: {
                    Label("Pi", systemImage: "terminal")
                }
            }
            .navigationTitle("Apple Orchestrator AI")
        } detail: {
            CoderEffortsView()
        }
        .environment(appState)
    }
}
