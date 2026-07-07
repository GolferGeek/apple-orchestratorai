import SwiftUI

struct VoiceCommandView: View {
    @Environment(AppState.self) private var appState
    @FocusState private var commandFocused: Bool

    var body: some View {
        @Bindable var appState = appState

        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(alignment: .leading, spacing: 10) {
                Text(appState.voicePrompt)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    TextField("Say or type a command", text: $appState.voiceCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .focused($commandFocused)
                        .onSubmit {
                            appState.submitVoiceCommand()
                        }

                    Button {
                        appState.submitVoiceCommand()
                    } label: {
                        Label("Send", systemImage: "arrow.up.circle.fill")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }

            quickCommands

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(appState.voiceLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(line.hasPrefix("You:") ? Color.blue.opacity(0.10) : Color.gray.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(22)
        .navigationTitle("Voice")
        .onAppear {
            commandFocused = true
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Command")
                    .font(.largeTitle.weight(.semibold))
                Text("Use macOS dictation in the command field, or type while we wire native speech recognition.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.speakPrompt()
            } label: {
                Label("Speak Prompt", systemImage: "speaker.wave.2")
            }
        }
    }

    private var quickCommands: some View {
        HStack(spacing: 10) {
            Button {
                appState.runQuickCommand("show coder efforts")
            } label: {
                Label("Efforts", systemImage: "hammer")
            }

            Button {
                appState.runQuickCommand("check Hermes")
            } label: {
                Label("Hermes", systemImage: "bolt.horizontal")
            }

            Button {
                appState.runQuickCommand("check Pi")
            } label: {
                Label("Pi", systemImage: "terminal")
            }

            Button {
                appState.runQuickCommand("help")
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        }
        .buttonStyle(.bordered)
    }
}
