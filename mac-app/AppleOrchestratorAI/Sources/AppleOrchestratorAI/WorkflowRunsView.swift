import SwiftUI

struct WorkflowRunsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Runs and Outputs")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button {
                        appState.refreshLocalState()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                if appState.workflowRuns.isEmpty {
                    EmptyPanel(title: "No run records found", detail: "Hermes run records will appear here when written to Apple local persistence.")
                } else {
                    ForEach(appState.workflowRuns) { run in
                        WorkflowRunCard(run: run)
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct WorkflowRunCard: View {
    let run: WorkflowRunRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.workflowName)
                        .font(.headline)
                    Text("\(run.client.name) / \(run.matter.name)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: run.status)
            }

            LabeledContent("Run", value: run.id)
            LabeledContent("Profile", value: run.profileId)
            LabeledContent("Started", value: run.startedAt)

            GenericTimelineBlock(title: "Timeline", stages: run.stages)

            if let humanReview = run.humanReview {
                HumanReviewBlock(review: humanReview)
            }

            ForEach(run.outputs) { output in
                OutputBlock(output: output)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct HumanReviewBlock: View {
    let review: HumanReviewRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: review.status)
            }
            Text(review.summary)
                .foregroundStyle(.secondary)
            ForEach(review.segments) { segment in
                HStack {
                    Text(segment.label)
                    Spacer()
                    Text(segment.decision ?? segment.status)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .padding(12)
        .background(.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct OutputBlock: View {
    let output: OutputEnvelope

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(output.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: output.type)
            }
            Text(output.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
