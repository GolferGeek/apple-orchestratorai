import SwiftUI

struct WorkflowsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(appState.workflows) { workflow in
                    WorkflowRow(workflow: workflow)
                }

                if appState.workflows.isEmpty {
                    EmptyStateView(
                        title: "No workflows found",
                        detail: "The app did not find workflow JSON under workflows/legal."
                    )
                }
            }
            .padding(20)
        }
    }
}

struct WorkflowRow: View {
    let workflow: WorkflowSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workflow.name)
                        .font(.headline)
                    Text("\(workflow.domain) / \(workflow.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(workflow.status.uppercased())
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .separatorColor).opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(workflow.summary)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(workflow.path)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
