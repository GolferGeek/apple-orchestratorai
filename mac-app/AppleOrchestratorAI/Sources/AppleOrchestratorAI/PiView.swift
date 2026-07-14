import SwiftUI

struct PiView: View {
    @Environment(AppState.self) private var appState
    @State private var showRawResponse = false

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                console

                if !appState.piConsoleEvents.isEmpty || appState.isPiConsoleRunning {
                    PiActivityBlock(events: appState.piConsoleEvents, isRunning: appState.isPiConsoleRunning)
                }

                if !appState.piConsoleRawResponse.isEmpty {
                    DisclosureGroup("Raw Pi Response", isExpanded: $showRawResponse) {
                        Text(appState.piConsoleRawResponse)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                diagnostics
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .navigationTitle("Pi")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Pi Runtime")
                .font(.title2.weight(.semibold))
            Text("Use this advanced panel to talk to the on-Mac Pi harness and inspect its messages, events, and approved tool calls.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var console: some View {
        @Bindable var appState = appState

        return GroupBox("Pi Prompt") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $appState.piConsolePrompt)
                    .font(.body)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    Picker("Model", selection: $appState.piConsoleModel) {
                        Text("Gemma 4 E4B").tag("gemma4:e4b-mlx")
                        Text("Qwen 3.6 27B").tag("qwen3.6:27b-mlx")
                        Text("Qwen 3.6 35B").tag("qwen3.6:35b-mlx")
                    }
                    .frame(width: 230)

                    Toggle("Allow approved workflow tools", isOn: $appState.piConsoleAllowsTools)
                        .toggleStyle(.checkbox)

                    Spacer()

                    Button {
                        appState.clearPiConsole()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Clear Pi console")
                    .disabled(appState.isPiConsoleRunning)

                    Button {
                        appState.runPiConsolePrompt()
                    } label: {
                        Label(appState.isPiConsoleRunning ? "Running" : "Run Prompt", systemImage: appState.isPiConsoleRunning ? "hourglass" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isPiConsoleRunning || appState.piConsolePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Text(appState.piConsoleStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("Pi Diagnostics") {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        appState.checkPi()
                    } label: {
                        Label("Check Pi", systemImage: "checkmark.circle")
                    }
                    ProbeOutput(text: appState.piOutput)
                }
                .padding(.top, 8)
            }

            DisclosureGroup("Local Services") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Checks the local Ollama endpoint and installed models. Workflow agents continue to define their own model policy.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button {
                        appState.checkRuntime()
                    } label: {
                        Label("Check Local Services", systemImage: "cpu")
                    }
                    ProbeOutput(text: appState.runtimeOutput)
                }
                .padding(.top, 8)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PiActivityBlock: View {
    let events: [WorkflowRunEvent]
    let isRunning: Bool

    private var messages: [WorkflowRunEvent] {
        events.filter {
            !$0.isPiToolEvent &&
            $0.type != "runtime.message.updated" &&
            $0.type != "runtime.message.started" &&
            $0.type != "runtime.message.completed"
        }
    }

    private var toolCalls: [WorkflowRunEvent] {
        events.filter(\.isPiToolEvent)
    }

    private var assistantResponse: String? {
        events.reversed().first(where: { event in
            event.piMessageRole == "assistant" && event.piMessageText != nil
        })?.piMessageText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Pi Activity")
                    .font(.headline)
                Spacer()
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text("live")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                StatusBadge(text: "\(events.count) events")
            }

            if let assistantResponse {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Response")
                        .font(.subheadline.weight(.semibold))
                    Text(assistantResponse)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if isRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Pi is preparing a response.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if !messages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Messages and Events")
                        .font(.subheadline.weight(.semibold))
                    ForEach(messages.suffix(12)) { event in
                        PiEventRow(event: event)
                    }
                }
            }

            if !toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tool Calls")
                        .font(.subheadline.weight(.semibold))
                    ForEach(toolCalls.suffix(30)) { event in
                        PiEventRow(event: event)
                    }
                }
            } else if isRunning {
                Text("No tools have been called.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.blue.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PiEventRow: View {
    let event: WorkflowRunEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.type)
                    .font(.callout.weight(.medium))
                if let toolName = event.piToolName {
                    Text(toolName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Text(event.timestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let message = event.piMessageText {
                Text(message)
                    .font(.callout)
            }
            HStack(spacing: 10) {
                if let skill = event.skillId { Label(skill, systemImage: "wand.and.stars") }
                if let model = event.modelName { Label(model, systemImage: "cpu") }
                if let status = event.status { Label(status, systemImage: "circle.fill") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct ProbeOutput: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
