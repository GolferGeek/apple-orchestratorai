import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Orchestrator AI")
                    .font(.title2.weight(.semibold))
                Text("Mac-first workflow runtime with Hermes skills")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusPill(status: appState.readiness.status)

            Button {
                Task {
                    await appState.refresh()
                }
            } label: {
                if appState.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .help("Refresh readiness")
            .disabled(appState.isRefreshing)
        }
        .padding(20)
    }
}
