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
    @Environment(AppState.self) private var appState
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

            if workflow.id == "document-onboarding" {
                HStack {
                    Button {
                        appState.startDocumentOnboardingRun()
                    } label: {
                        Label("Run Document Onboarding", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        appState.explainWorkflow(workflow)
                    } label: {
                        Label("Explain", systemImage: "questionmark.circle")
                    }

                    Button {
                        appState.runDocumentOnboardingDryRun()
                    } label: {
                        Label("Dry Run", systemImage: "hammer")
                    }
                }
            } else {
                Button {
                    appState.explainWorkflow(workflow)
                } label: {
                    Label("Explain", systemImage: "questionmark.circle")
                }
            }

            LabeledContent("Domain", value: workflow.domain)
            LabeledContent("Human review", value: workflow.humanInteraction)
            LabeledContent("Default local model", value: workflow.defaultLocalModel)

            GenericListBlock(title: "Launch Modes", items: workflow.launchModes)
            GenericTimelineBlock(title: "Stages", stages: workflow.stages.map {
                WorkflowStageRecord(id: $0, name: $0.replacingOccurrences(of: "_", with: " ").capitalized, status: "defined", summary: "Defined in workflow JSON.")
            })

            if let plan = appState.workflowExecutionPlans[workflow.id] {
                WorkflowExecutionPlanBlock(plan: plan)
            }

            if appState.workflowExplanation?.workflowId == workflow.id {
                WorkflowExplanationBlock(explanation: appState.workflowExplanation!)
            } else if appState.workflowExplanationStatus.contains(workflow.name) {
                Text(appState.workflowExplanationStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WorkflowExecutionPlanBlock: View {
    let plan: WorkflowExecutionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Execution Plan")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: plan.mode)
            }

            ForEach(plan.stages) { stage in
                WorkflowExecutionStageBlock(stage: stage)
            }

            if !plan.humanCheckpoints.isEmpty {
                GenericListBlock(
                    title: "Human Checkpoints",
                    items: plan.humanCheckpoints.map {
                        "\($0.id): \($0.reviewMode), decisions: \($0.allowedDecisions.joined(separator: ", "))"
                    }
                )
            }
        }
        .padding(12)
        .background(.teal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WorkflowExecutionStageBlock: View {
    let stage: WorkflowExecutionStage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stage.name)
                    .font(.callout.weight(.semibold))
                Spacer()
                StatusBadge(text: stage.execution)
            }

            Text("\(stage.graphId) / \(stage.subgraphId ?? "root")")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(stage.workUnits) { workUnit in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(workUnit.name)
                            .font(.callout)
                        Spacer()
                        if workUnit.optional == true {
                            StatusBadge(text: "optional")
                        }
                    }

                    Text(workUnit.skillId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if !workUnit.outputs.isEmpty {
                        Text("Outputs: \(workUnit.outputs.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WorkflowExplanationBlock: View {
    let explanation: WorkflowExplanation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(explanation.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: explanation.target.type)
            }

            Text(explanation.summary)
                .foregroundStyle(.secondary)

            ForEach(explanation.sections) { section in
                GenericListBlock(title: section.heading, items: section.items)
            }
        }
        .padding(12)
        .background(.indigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
