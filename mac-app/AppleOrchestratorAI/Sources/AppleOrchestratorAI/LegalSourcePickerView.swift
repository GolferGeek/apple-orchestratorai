import SwiftUI

struct LegalSourcePickerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Legal Source Picker")
                            .font(.title2.weight(.semibold))
                        Text(appState.legalSourceStatus)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        appState.loadLegalClients()
                    } label: {
                        Label("Ask Pi", systemImage: "arrow.clockwise")
                    }
                }

                PickerColumn(
                    title: "Clients",
                    options: appState.legalSourceClients,
                    selectedIds: Set([appState.legalSourceSelection.client?.id].compactMap { $0 }),
                    emptyText: "Ask Hermes for clients."
                ) { option in
                    appState.selectLegalClient(option)
                }

                PickerColumn(
                    title: "Matters",
                    options: appState.legalSourceMatters,
                    selectedIds: Set([appState.legalSourceSelection.matter?.id].compactMap { $0 }),
                    emptyText: "Select a client to ask Hermes for matters."
                ) { option in
                    appState.selectLegalMatter(option)
                }

                PickerColumn(
                    title: "Documents",
                    options: appState.legalSourceDocuments,
                    selectedIds: Set(appState.legalSourceSelection.documents.map(\.id)),
                    emptyText: "Select a matter to ask Hermes for documents."
                ) { option in
                    appState.toggleLegalDocument(option)
                }

                HStack {
                    Spacer()
                    Button {
                        appState.startDocumentOnboardingRun()
                    } label: {
                        Label("Run Document Onboarding", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.legalSourceSelection.client == nil || appState.legalSourceSelection.matter == nil)
                }
            }
            .padding(20)
        }
    }
}

private struct PickerColumn: View {
    let title: String
    let options: [LegalSourceOption]
    let selectedIds: Set<String>
    let emptyText: String
    let action: (LegalSourceOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if options.isEmpty {
                EmptyPanel(title: "No \(title.lowercased()) loaded", detail: emptyText)
            } else {
                ForEach(options) { option in
                    Button {
                        action(option)
                    } label: {
                        HStack {
                            Image(systemName: selectedIds.contains(option.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIds.contains(option.id) ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(.body.weight(.medium))
                                Text(option.subtitle)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(option.source)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
