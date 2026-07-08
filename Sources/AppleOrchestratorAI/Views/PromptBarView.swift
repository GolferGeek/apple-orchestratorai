import SwiftUI

struct PromptBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                TextField("Ask Hermes to run or explain a workflow...", text: $appState.promptText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.vertical, 10)

                Button {
                    Task {
                        await appState.submitPrompt()
                    }
                } label: {
                    if appState.isSubmittingPrompt {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .help("Send prompt")
                .disabled(appState.isSubmittingPrompt || appState.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
