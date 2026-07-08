import SwiftUI

struct WorkflowRunsView: View {
    @Environment(AppState.self) private var appState
    @State private var runIdToSubscribe = ""

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

                LiveHermesEventSubscriptionView(runIdToSubscribe: $runIdToSubscribe)

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

private struct LiveHermesEventSubscriptionView: View {
    @Environment(AppState.self) private var appState
    @Binding var runIdToSubscribe: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Live Hermes Events")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: appState.hermesEventStreamStatus)
            }

            HStack {
                TextField("Hermes run id", text: $runIdToSubscribe)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        appState.subscribeToHermesRunEvents(runId: runIdToSubscribe)
                    }

                Button {
                    appState.subscribeToHermesRunEvents(runId: runIdToSubscribe)
                } label: {
                    Label("Subscribe", systemImage: "dot.radiowaves.left.and.right")
                }

                Button {
                    appState.stopHermesEventStream()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
            }

            if !appState.liveHermesEvents.isEmpty {
                EventStreamBlock(events: appState.liveHermesEvents, plan: nil)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WorkflowRunCard: View {
    @Environment(AppState.self) private var appState
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

            HStack {
                if run.status == "running" || run.status == "waiting_for_human" || run.status == "queued" {
                    Button {
                        appState.pauseWorkflowRun(runId: run.id)
                    } label: {
                        Label("Pause", systemImage: "pause.circle")
                    }

                    Button {
                        appState.stopWorkflowRun(runId: run.id)
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                }

                if run.status == "paused" {
                    Button {
                        appState.resumeWorkflowRun(runId: run.id)
                    } label: {
                        Label("Resume", systemImage: "play.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if appState.activeHermesEventRunIds.contains(run.id) {
                    StatusBadge(text: "streaming")
                }
            }

            LabeledContent("Run", value: run.id)
            LabeledContent("Profile", value: run.profileId)
            LabeledContent("Started", value: run.startedAt)

            GenericTimelineBlock(title: "Timeline", stages: run.stages)

            if let progress = appState.plannedProgress(for: run) {
                PlannedRunProgressBlock(progress: progress)
            }

            if !run.events.isEmpty {
                EventStreamBlock(events: run.events, plan: appState.workflowExecutionPlans[run.workflowId])
            }

            if let humanReview = run.humanReview {
                HumanReviewBlock(runId: run.id, review: humanReview)
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

private struct PlannedRunProgressBlock: View {
    let progress: PlannedRunProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Planned Progress")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: "\(progress.completedWorkUnitCount)/\(progress.totalWorkUnitCount)")
            }

            if let active = progress.latestActiveWorkUnit {
                Text("Latest: \(active.name)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(progress.stages) { stage in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(stage.name)
                            .font(.callout.weight(.semibold))
                        Spacer()
                        StatusBadge(text: stage.status)
                        StatusBadge(text: stage.execution)
                    }

                    ForEach(stage.workUnits) { workUnit in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: iconName(for: workUnit.status))
                                .foregroundStyle(color(for: workUnit.status))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(workUnit.name)
                                        .font(.callout)
                                    if workUnit.optional {
                                        StatusBadge(text: "optional")
                                    }
                                }
                                Text(workUnit.skillId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            Spacer()
                            StatusBadge(text: workUnit.status)
                        }
                    }
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(.teal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func iconName(for status: String) -> String {
        switch status {
        case "completed":
            "checkmark.circle.fill"
        case "running", "started":
            "play.circle.fill"
        default:
            "circle"
        }
    }

    private func color(for status: String) -> Color {
        switch status {
        case "completed":
            .green
        case "running", "started":
            .orange
        default:
            .secondary
        }
    }
}

private struct EventStreamBlock: View {
    let events: [WorkflowRunEvent]
    let plan: WorkflowExecutionPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event Stream")
                .font(.subheadline.weight(.semibold))

            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(event.type)
                            .font(.callout.weight(.medium))
                        Spacer()
                        Text(event.timestamp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        if let stageId = event.stageId {
                            Label(stageName(stageId), systemImage: "square.stack.3d.up")
                        }
                        if let workUnitId = event.workUnitId {
                            Label(workUnitName(workUnitId), systemImage: "hammer")
                        }
                        if let skillId = event.skillId {
                            Label(skillId, systemImage: "puzzlepiece.extension")
                        }
                        if let reviewId = event.reviewId {
                            Label(reviewId, systemImage: "person.crop.circle.badge.checkmark")
                        }
                        if let rawHermesRunId = event.rawHermesRunId, !rawHermesRunId.isEmpty {
                            Label(rawHermesRunId, systemImage: "bolt.horizontal")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let summary = event.summary {
                        Text(summary)
                            .font(.callout)
                    }

                    if let message = event.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let progress = event.progress {
                        ProgressView(value: progress.current, total: progress.total) {
                            Text("\(Int(progress.current)) of \(Int(progress.total)) \(progress.unit)")
                                .font(.caption)
                        }
                    }

                    if let outputs = event.outputs, !outputs.isEmpty {
                        ForEach(outputs) { output in
                            Label(output.title ?? output.id, systemImage: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stageName(_ stageId: String) -> String {
        plan?.stages.first(where: { $0.id == stageId })?.name ?? stageId
    }

    private func workUnitName(_ workUnitId: String) -> String {
        plan?.stages
            .flatMap(\.workUnits)
            .first(where: { $0.id == workUnitId })?
            .name ?? workUnitId
    }
}

private struct HumanReviewBlock: View {
    @Environment(AppState.self) private var appState
    let runId: String
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

            if review.status == "requested" {
                HStack {
                    Button {
                        appState.approveHumanReview(runId: runId, review: review)
                    } label: {
                        Label("Approve", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        appState.requestHumanReviewChanges(runId: runId, review: review)
                    } label: {
                        Label("Request Changes", systemImage: "arrow.uturn.backward.circle")
                    }
                }
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
