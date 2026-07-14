import SwiftUI

struct DocumentOnboardingLaunchSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var source = Source.localFiles

    private enum Source: String, CaseIterable, Identifiable {
        case localFiles = "Local Files"
        case connectedMatter = "Client Matter"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Document Onboarding")
                        .font(.title2.weight(.semibold))
                    Text("Choose documents first. Pi resolves and processes the source after launch.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close")
            }

            Picker("Source", selection: $source) {
                ForEach(Source.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch source {
                case .localFiles:
                    localFiles
                case .connectedMatter:
                    connectedMatter
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack {
                Text(source == .localFiles
                     ? "Selected files are copied into app-owned local storage when you start."
                     : "Pi resolves the selected client, matter, and documents through approved tools or MCPs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                Button {
                    appState.startDocumentOnboardingRun()
                } label: {
                    Label("Start Workflow", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
            }
        }
        .padding(22)
        .frame(minWidth: 700, minHeight: 500)
        .onChange(of: source) { _, next in
            if next == .connectedMatter { appState.loadLegalClients() }
        }
    }

    private var canStart: Bool {
        switch source {
        case .localFiles:
            !appState.documentOnboardingLocalFiles.isEmpty
        case .connectedMatter:
            appState.legalSourceSelection.client != nil && appState.legalSourceSelection.matter != nil && !appState.legalSourceSelection.documents.isEmpty
        }
    }

    private var localFiles: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Documents")
                    .font(.headline)
                Spacer()
                if !appState.documentOnboardingLocalFiles.isEmpty {
                    Button("Clear", role: .destructive) {
                        appState.clearDocumentOnboardingFiles()
                    }
                }
                Button {
                    appState.chooseDocumentOnboardingFiles()
                } label: {
                    Label("Add Files", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if appState.documentOnboardingLocalFiles.isEmpty {
                ContentUnavailableView(
                    "No documents selected",
                    systemImage: "doc.badge.plus",
                    description: Text("Add one or more files. You can reopen the picker as often as needed before starting."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.documentOnboardingLocalFiles) { file in
                        HStack(spacing: 10) {
                            Image(systemName: "doc")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name).font(.body.weight(.medium))
                                Text(file.location).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button {
                                appState.removeDocumentOnboardingFile(file)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove \(file.name)")
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var connectedMatter: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Approved Client Sources").font(.headline)
                    Spacer()
                    Button {
                        appState.loadLegalClients()
                    } label: {
                        Label("Ask Pi", systemImage: "arrow.clockwise")
                    }
                }
                Text(appState.legalSourceStatus).font(.caption).foregroundStyle(.secondary)
                SourceOptionList(title: "Clients", options: appState.legalSourceClients, selected: Set([appState.legalSourceSelection.client?.id].compactMap { $0 })) { appState.selectLegalClient($0) }
                SourceOptionList(title: "Matters", options: appState.legalSourceMatters, selected: Set([appState.legalSourceSelection.matter?.id].compactMap { $0 })) { appState.selectLegalMatter($0) }
                SourceOptionList(title: "Documents", options: appState.legalSourceDocuments, selected: Set(appState.legalSourceSelection.documents.map(\.id))) { appState.toggleLegalDocument($0) }
            }
        }
    }
}

private struct SourceOptionList: View {
    let title: String
    let options: [LegalSourceOption]
    let selected: Set<String>
    let action: (LegalSourceOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            if options.isEmpty {
                Text("No (title.lowercased()) loaded yet.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(options) { option in
                    Button { action(option) } label: {
                        HStack {
                            Image(systemName: selected.contains(option.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(option.id) ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(option.label)
                                Text(option.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}
