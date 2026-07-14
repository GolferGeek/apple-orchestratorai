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

            if !appState.recentModalSurfaces.isEmpty {
                recentSurfaces
            }

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
                Text("Talk to your personal assistant, or type a command.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.speakPrompt()
            } label: {
                Label("Speak Prompt", systemImage: "speaker.wave.2")
            }

            Button {
                appState.toggleListening()
            } label: {
                Label(appState.isListening ? "Stop" : "Listen", systemImage: appState.isListening ? "mic.slash" : "mic")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var quickCommands: some View {
        HStack(spacing: 10) {
            Text(appState.speechStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                appState.runQuickCommand("show personal")
            } label: {
                Label("Personal", systemImage: "person.crop.circle")
            }

            Button {
                appState.runQuickCommand("show coder")
            } label: {
                Label("Coder", systemImage: "hammer")
            }

            Button {
                appState.runQuickCommand("what is on my calendar")
            } label: {
                Label("Calendar", systemImage: "calendar")
            }

            Button {
                appState.runQuickCommand("show personal")
            } label: {
                Label("Personal", systemImage: "person.crop.circle")
            }

            Button {
                appState.runQuickCommand("what reminders are open")
            } label: {
                Label("Reminders", systemImage: "checklist")
            }

            Button {
                appState.runQuickCommand("help")
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        }
        .buttonStyle(.bordered)
    }

    private var recentSurfaces: some View {
        HStack(spacing: 10) {
            Text("Open again")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(appState.recentModalSurfaces) { surface in
                Button {
                    appState.openModal(surface)
                } label: {
                    Label(surface.title, systemImage: surface.symbolName)
                }
            }
        }
        .buttonStyle(.bordered)
    }
}
