import SwiftUI

struct CoderEffortsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()

            if let surface = appState.surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EffortSectionView(title: "Inbox", items: surface.sections.inbox)
                        ActiveEffortSectionView(title: "Current", efforts: surface.sections.current)
                        ActiveEffortSectionView(title: "Future", efforts: surface.sections.future)
                        ActiveEffortSectionView(title: "Archive", efforts: surface.sections.archive)
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView("No Efforts Loaded", systemImage: "tray", description: Text(appState.statusMessage))
            }
        }
        .navigationTitle("Coder Efforts")
    }

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Coder Efforts")
                    .font(.title2.weight(.semibold))
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.reloadEfforts()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
        }
        .padding(16)
    }
}

private struct EffortSectionView: View {
    let title: String
    let items: [InboxItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, count: items.count)
            if items.isEmpty {
                EmptyRow(text: "No inbox intentions.")
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .font(.headline)
                        if let summary = item.summary, !summary.isEmpty {
                            Text(summary)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.path)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct ActiveEffortSectionView: View {
    let title: String
    let efforts: [EffortItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, count: efforts.count)
            if efforts.isEmpty {
                EmptyRow(text: "No \(title.lowercased()) efforts.")
            } else {
                ForEach(efforts) { effort in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(effort.title)
                                .font(.headline)
                            Spacer()
                            Text("\(effort.turn.owner) • \(effort.turn.state)")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(effort.hasBlockingQuestions ? Color.red.opacity(0.15) : Color.blue.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Text(effort.turn.reason)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 14) {
                            Label("\(effort.questionCount)", systemImage: "questionmark.circle")
                            Label("\(effort.artifactCount)", systemImage: "doc.on.doc")
                            Text(effort.path)
                                .foregroundStyle(.tertiary)
                        }
                        .font(.caption)
                    }
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary)
                .clipShape(Capsule())
        }
    }
}

private struct EmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
