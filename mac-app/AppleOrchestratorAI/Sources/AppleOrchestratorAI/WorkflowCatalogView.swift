import SwiftUI

struct WorkflowCatalogView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Workflow Catalog")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button {
                        appState.refreshLocalState()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                if appState.workflows.isEmpty {
                    EmptyPanel(title: "No workflows found", detail: "Add workflow JSON under workflows/ and refresh.")
                } else {
                    ForEach(appState.workflows) { workflow in
                        WorkflowCatalogCard(workflow: workflow)
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct WorkflowCatalogCard: View {
    let workflow: WorkflowCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.name)
                        .font(.headline)
                    Text(workflow.description)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: workflow.status)
            }

            LabeledContent("Domain", value: workflow.domain)
            LabeledContent("Human review", value: workflow.humanInteraction)
            LabeledContent("Default local model", value: workflow.defaultLocalModel)

            GenericListBlock(title: "Launch Modes", items: workflow.launchModes)
            GenericTimelineBlock(title: "Stages", stages: workflow.stages.map {
                WorkflowStageRecord(id: $0, name: $0.replacingOccurrences(of: "_", with: " ").capitalized, status: "defined", summary: "Defined in workflow JSON.")
            })
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
