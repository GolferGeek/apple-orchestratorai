import AppKit
import SwiftUI
import WebKit

struct WorkflowRunsView: View {
    @Environment(AppState.self) private var appState
    let workflowId: String?
    let title: String
    @State private var selectedRunId: String?

    init(workflowId: String? = nil, title: String = "Workflow Runs") {
        self.workflowId = workflowId
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    appState.refreshLocalState()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if filteredRuns.isEmpty {
                EmptyPanel(title: "No run records found", detail: "Pi workflow run records will appear here when written to Apple local persistence.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                runInspector
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            selectDefaultRunIfNeeded()
        }
        .onChange(of: appState.workflowRuns) { _, _ in
            selectDefaultRunIfNeeded()
        }
        .onChange(of: workflowId) { _, _ in
            selectedRunId = nil
            selectDefaultRunIfNeeded()
        }
        .onChange(of: selectedRunId) { _, newValue in
            guard let newValue else { return }
            appState.followLocalRuntimeRun(runId: newValue)
        }
    }

    private var selectedRun: WorkflowRunRecord? {
        if let selectedRunId, let run = filteredRuns.first(where: { $0.id == selectedRunId }) {
            return run
        }
        return filteredRuns.first
    }

    private var activeRuns: [WorkflowRunRecord] {
        filteredRuns.filter { Self.isActive($0.status) }
    }

    private var completedRuns: [WorkflowRunRecord] {
        filteredRuns.filter { !Self.isActive($0.status) }
    }

    private var filteredRuns: [WorkflowRunRecord] {
        guard let workflowId else { return appState.workflowRuns }
        return appState.workflowRuns.filter { $0.workflowId == workflowId }
    }

    private var runInspector: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Workflow Runs")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    StatusBadge(text: "\(sortedRuns.count)")
                }

                List(selection: $selectedRunId) {
                    ForEach(sortedRuns) { run in
                        RunListRow(run: run, isSelected: run.id == selectedRunId)
                            .tag(run.id)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    }
                }
                .listStyle(.plain)
            }
            .frame(width: 430, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            Divider()

            List {
                if let selectedRun {
                    WorkflowRunCard(run: selectedRun)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                } else {
                    EmptyPanel(title: "Select a run", detail: "Choose a running or completed workflow to inspect its timeline, events, human review, and outputs.")
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .listStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sortedRuns: [WorkflowRunRecord] {
        filteredRuns.sorted { lhs, rhs in
            let lhsActive = Self.isActive(lhs.status)
            let rhsActive = Self.isActive(rhs.status)
            if lhsActive != rhsActive {
                return lhsActive && !rhsActive
            }
            return (lhs.completedAt ?? lhs.events.last?.timestamp ?? lhs.startedAt) > (rhs.completedAt ?? rhs.events.last?.timestamp ?? rhs.startedAt)
        }
    }

    private func selectRun(_ run: WorkflowRunRecord) {
        selectedRunId = run.id
    }

    private func selectDefaultRunIfNeeded() {
        guard selectedRunId == nil || !filteredRuns.contains(where: { $0.id == selectedRunId }) else {
            return
        }

        if let active = activeRuns.first {
            selectedRunId = active.id
            return
        }

        if let first = filteredRuns.first {
            selectedRunId = first.id
        }
    }

    private static func isActive(_ status: String) -> Bool {
        ["running", "reporting", "awaiting_review", "waiting_for_human", "queued", "paused"].contains(status)
    }
}

private struct RunListSection: View {
    let title: String
    let emptyTitle: String
    let runs: [WorkflowRunRecord]
    let selectedRunId: String?
    let onSelect: (WorkflowRunRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: "\(runs.count)")
            }

            if runs.isEmpty {
                Text(emptyTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(runs) { run in
                    RunListRow(run: run, isSelected: run.id == selectedRunId)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(run)
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction {
                        onSelect(run)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct RunListRow: View {
    let run: WorkflowRunRecord
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(run.workflowName)
                        .font(.callout.weight(.medium))
                    Spacer()
                    Text(RunTimeFormatter.relativeRunTime(for: run))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusBadge(text: run.status)
                }

                Text("\(run.client.name) / \(run.matter.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(run.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let latest = run.events.last?.summary ?? run.events.last?.type {
                    Text(latest)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color(nsColor: .textBackgroundColor).opacity(0.65))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        switch run.status {
        case "completed":
            "checkmark.circle.fill"
        case "failed", "cancelled", "stopped":
            "xmark.circle.fill"
        case "interrupted":
            "exclamationmark.circle.fill"
        case "awaiting_review", "waiting_for_human":
            "person.crop.circle.badge.exclamationmark"
        default:
            "play.circle.fill"
        }
    }

    private var iconColor: Color {
        switch run.status {
        case "completed":
            .green
        case "failed", "cancelled", "stopped":
            .red
        case "interrupted":
            .orange
        case "awaiting_review", "waiting_for_human":
            .blue
        default:
            .orange
        }
    }
}

private struct LiveRuntimeEventSubscriptionView: View {
    @Environment(AppState.self) private var appState
    @Binding var runIdToSubscribe: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Live Runtime Events")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: appState.hermesEventStreamStatus)
            }

            HStack {
                TextField("Run id", text: $runIdToSubscribe)
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
                EventStreamBlock(events: Array(appState.liveHermesEvents.suffix(60)), agent: nil)
                    .frame(maxHeight: 180)
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
    @State private var showProgress = false
    @State private var showAgentOutputs = false
    @State private var showOutputContracts = false
    @State private var showFiles = false
    @State private var showEventStream = false
    @State private var previewOutput: OutputEnvelope?
    @State private var showDeleteConfirmation = false

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
                if appState.canControlLocalWorkflowRun(runId: run.id) {
                    if run.status == "paused" {
                        Button {
                            appState.resumeWorkflowRun(runId: run.id)
                        } label: {
                            Label("Resume", systemImage: "play.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Resume this workflow run")
                    } else {
                        Button {
                            appState.pauseWorkflowRun(runId: run.id)
                        } label: {
                            Label("Pause", systemImage: "pause.circle")
                        }
                        .buttonStyle(.bordered)
                        .help("Pause this workflow run")
                    }

                    Button(role: .destructive) {
                        appState.stopWorkflowRun(runId: run.id)
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .buttonStyle(.bordered)
                    .help("Stop this workflow run")
                }
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete this workflow run")
                .accessibilityLabel("Delete workflow run")
            }

            LabeledContent("Run", value: run.id)
            LabeledContent("Profile", value: run.profileId)
            LabeledContent("Started", value: "\(RunTimeFormatter.relativeRunTime(for: run)) · \(RunTimeFormatter.displayDate(run.startedAt))")
            if let completedAt = run.completedAt {
                LabeledContent("Completed", value: RunTimeFormatter.displayDate(completedAt))
            }

            let outputPacket = appState.outputPacket(for: run)
            let finalOutputReleased = run.status == "completed"
            let visibleOutputs = extraOutputs(excluding: outputPacket, finalOutputReleased: finalOutputReleased)
            FinalOutputBlock(outputs: visibleOutputs, packet: outputPacket, isReleased: finalOutputReleased) { output in
                previewOutput = output
            }

            CurrentActivityBlock(run: run)

            if hasProgress {
                DetailToggleButton(
                    title: "Progress",
                    subtitle: progressSubtitle,
                    isExpanded: $showProgress
                )

                if showProgress {
                    if let progress = appState.plannedProgress(for: run) {
                        PlannedRunProgressBlock(progress: progress)
                    } else {
                        GenericTimelineBlock(title: "Progress", stages: run.stages)
                    }
                }
            }

            if let humanReview = run.humanReview {
                HumanReviewBlock(runId: run.id, review: humanReview)
            }

            if !run.entries.isEmpty {
                DetailToggleButton(
                    title: "What Got Done",
                    subtitle: "\(run.entries.count) recent updates",
                    isExpanded: $showAgentOutputs
                )

                if showAgentOutputs {
                    RunEntriesBlock(entries: run.entries, events: run.events)
                }
            }

            if !outputPacket.items.isEmpty {
                DetailToggleButton(
                    title: "Output Contracts",
                    subtitle: "\(outputPacket.fulfilledCount) available",
                    isExpanded: $showOutputContracts
                )

                if showOutputContracts {
                    OutputPacketBlock(packet: outputPacket)
                }
            }

            if !visibleOutputs.isEmpty {
                DetailToggleButton(
                    title: "Files",
                    subtitle: "\(visibleOutputs.count) artifacts",
                    isExpanded: $showFiles
                )

                if showFiles {
                    ForEach(visibleOutputs) { output in
                        OutputBlock(output: output) {
                            previewOutput = output
                        }
                    }
                }
            }

            if !run.events.isEmpty {
                DetailToggleButton(
                    title: "Raw Event Stream",
                    subtitle: "\(run.events.count) recent events",
                    isExpanded: $showEventStream
                )

                if showEventStream {
                    EventStreamBlock(events: run.events, agent: appState.workflowAgents[run.workflowId])
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(item: $previewOutput) { output in
            OutputPreviewSheet(output: output)
                .frame(minWidth: 760, minHeight: 620)
        }
        .confirmationDialog(
            "Delete this workflow run?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Run", role: .destructive) {
                appState.deleteWorkflowRun(runId: run.id)
            }
        } message: {
            Text("This removes the run, its events, staged documents, review data, generated artifacts, and log. The workflow definition remains available.")
        }
    }

    private func extraOutputs(excluding packet: WorkflowOutputPacket, finalOutputReleased: Bool) -> [OutputEnvelope] {
        let packetIds = Set(packet.items.map(\.id))
        return run.outputs.filter { output in
            guard !packetIds.contains(output.id) else { return false }
            guard finalOutputReleased else {
                return !output.isMarkdownLike && !output.title.localizedCaseInsensitiveContains("report")
            }
            return true
        }
    }

    private var hasProgress: Bool {
        appState.plannedProgress(for: run) != nil || !run.stages.isEmpty
    }

    private var progressSubtitle: String {
        if let progress = appState.plannedProgress(for: run) {
            if let active = progress.latestActiveWorkUnit {
                return "Working on \(active.name)"
            }
            if progress.completedWorkUnitCount == progress.totalWorkUnitCount, progress.totalWorkUnitCount > 0 {
                return "All planned work is complete"
            }
            if progress.completedWorkUnitCount > 0 {
                return "\(progress.completedWorkUnitCount) completed"
            }
            return "Planned work"
        }

        return "\(run.stages.count) stages"
    }
}

private struct DetailToggleButton: View {
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct CurrentActivityBlock: View {
    let run: WorkflowRunRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Activity")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if let active = activeEvent {
                ActivityEventRow(title: "Running now", event: active)
            } else if let latest = run.events.last {
                ActivityEventRow(title: "Latest event", event: latest)
            } else {
                Text("No runtime events have been recorded for this run yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let latestEntry = run.entries.last {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest completed step")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        StatusBadge(text: friendlyPhase(for: latestEntry))
                        if let roleId = latestEntry.roleId {
                            Label(friendlyId(roleId), systemImage: "person.text.rectangle")
                        }
                        if let teamId = latestEntry.teamId {
                            Label(friendlyId(teamId), systemImage: "person.3")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(humanOutputSummary(for: latestEntry))
                        .font(.callout)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var activeEvent: WorkflowRunEvent? {
        let completedRoleIds = Set(run.events.filter { ["role.completed", "role.failed"].contains($0.type) }.compactMap(\.roleId))
        if let startedRole = run.events.last(where: { $0.type == "role.started" && $0.roleId.map { !completedRoleIds.contains($0) } == true }) {
            return startedRole
        }

        let completedTeamIds = Set(run.events.filter { ["team.completed", "team.failed"].contains($0.type) }.compactMap(\.teamId))
        if let startedTeam = run.events.last(where: { $0.type == "team.started" && $0.teamId.map { !completedTeamIds.contains($0) } == true }) {
            return startedTeam
        }

        let completedWorkUnitIds = Set(run.events.filter { ["work_unit.completed", "work_unit.failed"].contains($0.type) }.compactMap(\.workUnitId))
        return run.events.last(where: { $0.type == "work_unit.started" && $0.workUnitId.map { !completedWorkUnitIds.contains($0) } == true })
    }

    private func humanOutputSummary(for entry: WorkflowRunEntry) -> String {
        if entry.entryType.hasSuffix(".team_output") {
            return "The \(friendlyPhase(for: entry).lowercased()) team completed its part of the workflow."
        }
        if entry.entryType.contains("human_review") {
            return "The attorney review screen is ready."
        }
        if entry.entryType.contains("quality_review") || entry.entryType.contains("validation") {
            if entry.previewText.contains("\"status\": \"warning\"") || entry.previewText.contains("\"status\":\"warning\"") {
                return "Quality review found items that may need attention."
            }
            return "Quality review passed."
        }
        if entry.previewText.contains("selectedLanes") || entry.previewText.contains("confirmedLanes") {
            return "The workflow chose the legal review lanes needed for these documents."
        }
        if entry.previewText.contains("documentsMetadata") {
            return "The workflow extracted document types, dates, parties, obligations, and sensitivity flags."
        }
        if entry.previewText.contains("onboardingPacket") {
            return "The workflow gathered the client, matter, and document package."
        }
        if entry.entryType.contains("synthesis") {
            return "The workflow combined the specialist reviews into a single review packet."
        }
        return friendlyId(entry.entryType)
    }

    private func friendlyPhase(for entry: WorkflowRunEntry) -> String {
        if let workUnitId = entry.workUnitId {
            return friendlyId(workUnitId.replacingOccurrences(of: "document_onboarding.", with: ""))
        }
        return friendlyId(entry.entryType.components(separatedBy: ".").first ?? entry.entryType)
    }

    private func friendlyId(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            .joined(separator: " ")
    }
}

private struct ActivityEventRow: View {
    let title: String
    let event: WorkflowRunEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(RunTimeFormatter.displayEventTime(event.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                StatusBadge(text: event.type)
                if let workUnitId = event.workUnitId {
                    Label(workUnitId, systemImage: "hammer")
                }
                if let teamId = event.teamId {
                    Label(teamId, systemImage: "person.3")
                }
                if let roleId = event.roleId {
                    Label(roleId, systemImage: "person.text.rectangle")
                }
                if let agentId = event.agentId {
                    Label(agentId, systemImage: "brain")
                }
                if let modelName = event.modelName {
                    Label("Model: \(modelName)", systemImage: "cpu")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(event.summary ?? event.message ?? event.type)
                .font(.callout)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FinalOutputBlock: View {
    let outputs: [OutputEnvelope]
    let packet: WorkflowOutputPacket
    let isReleased: Bool
    let onPreview: (OutputEnvelope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Final Output", systemImage: "doc.text.fill")
                    .font(.headline)
                Spacer()
                if let statusText {
                    StatusBadge(text: statusText)
                }
            }

            if !isReleased {
                Text("The workflow is still running. Its report will be available here after the final wrap-up completes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let primary = primaryOutput {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(primary.title)
                                .font(.callout.weight(.semibold))
                            Text(primary.content.hasPrefix("/") ? primary.content : primary.content.truncated(to: 220))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button {
                            onPreview(primary)
                        } label: {
                            Label("View Report", systemImage: "doc.richtext")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Final report has not been produced yet. After human review approval, the workflow should enter wrap-up and report generation.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(isReleased && primaryOutput != nil ? .green.opacity(0.12) : .yellow.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var primaryOutput: OutputEnvelope? {
        outputs.first { $0.isMarkdownReport }
            ?? outputs.first { $0.isMarkdownLike }
            ?? packet.items.compactMap(\.output).first { $0.isMarkdownReport }
            ?? packet.items.compactMap(\.output).first { $0.isMarkdownLike }
            ?? outputs.first { $0.title.localizedCaseInsensitiveContains("report") && $0.content.hasPrefix("/") }
            ?? outputs.first { $0.content.hasPrefix("/") }
            ?? packet.items.compactMap(\.output).first
    }

    private var statusText: String? {
        if !isReleased {
            return "in progress"
        }
        if primaryOutput != nil {
            return "available"
        }
        if packet.items.contains(where: { $0.required }) && packet.items.count > 0 {
            return "\(packet.fulfilledCount)/\(packet.items.count)"
        }
        return nil
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
    let agent: WorkflowAgentNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Event Stream")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: "latest \(events.count)")
            }

            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(event.type)
                            .font(.callout.weight(.medium))
                        Spacer()
                        Text(RunTimeFormatter.displayEventTime(event.timestamp))
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
                        if let teamId = event.teamId {
                            Label(teamId, systemImage: "person.3")
                        }
                        if let roleId = event.roleId {
                            Label(roleId, systemImage: "person.text.rectangle")
                        }
                        if let agentId = event.agentId {
                            Label(agentId, systemImage: "brain")
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
                        let models = modelNames(for: event)
                        if models.isEmpty {
                            Label("No model call", systemImage: "cpu")
                        } else {
                            Label("Model: \(models.joined(separator: ", "))", systemImage: "cpu")
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
        findNode(id: stageId)?.name ?? stageId
    }

    private func workUnitName(_ workUnitId: String) -> String {
        findNode(id: workUnitId)?.name ?? workUnitId
    }

    private func findNode(id: String) -> WorkflowAgentNode? {
        guard let agent else { return nil }
        return findNode(id: id, in: agent)
    }

    private func findNode(id: String, in node: WorkflowAgentNode) -> WorkflowAgentNode? {
        if node.id == id { return node }
        for child in node.children {
            if let match = findNode(id: id, in: child) { return match }
        }
        return nil
    }

    private func modelNames(for event: WorkflowRunEvent) -> [String] {
        var candidates = [event.modelName]

        if let roleId = event.roleId {
            candidates += events.filter { $0.roleId == roleId }.map(\.modelName)
        } else if let teamId = event.teamId {
            candidates += events.filter { $0.teamId == teamId }.map(\.modelName)
        } else if let workUnitId = event.workUnitId {
            candidates += events.filter { $0.workUnitId == workUnitId }.map(\.modelName)
        }

        var seen = Set<String>()
        return candidates.compactMap { $0 }.filter { seen.insert($0).inserted }
    }
}

private struct RunEntriesBlock: View {
    let entries: [WorkflowRunEntry]
    let events: [WorkflowRunEvent]
    @State private var expandedEntryIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("What Got Done", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: "latest \(entries.count)")
            }

            ForEach(Array(entries.reversed())) { entry in
                WorkCompletedRow(
                    entry: entry,
                    modelName: modelName(for: entry),
                    isExpanded: expandedEntryIds.contains(entry.id),
                    onToggle: {
                        if expandedEntryIds.contains(entry.id) {
                            expandedEntryIds.remove(entry.id)
                        } else {
                            expandedEntryIds.insert(entry.id)
                        }
                    }
                )
            }
        }
        .padding(12)
        .background(.cyan.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func modelName(for entry: WorkflowRunEntry) -> String? {
        if let modelName = entry.modelName {
            return modelName
        }

        return events.last { event in
            event.modelName != nil
                && (entry.roleId == nil || event.roleId == entry.roleId)
                && (entry.teamId == nil || event.teamId == entry.teamId)
                && (entry.workUnitId == nil || event.workUnitId == entry.workUnitId)
        }?.modelName
    }
}

private struct WorkCompletedRow: View {
    let entry: WorkflowRunEntry
    let modelName: String?
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title)
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Text(RunTimeFormatter.displayDate(entry.timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        StatusBadge(text: phase)
                        if let teamId = entry.teamId {
                            Text(friendlyId(teamId))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let modelName {
                            Label(modelName, systemImage: "cpu")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if isExpanded {
                Divider()
                Text("Technical detail")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(entry.previewText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    private var title: String {
        if entry.entryType.hasSuffix(".team_output") {
            return "\(phase) finished"
        }
        if entry.entryType.contains("quality_review") || entry.entryType.contains("validation") {
            return "\(phase) checked"
        }
        if entry.entryType.contains("routing") {
            return "Review lanes selected"
        }
        if entry.entryType.contains("metadata") {
            return "Document details extracted"
        }
        if entry.entryType.contains("source") || entry.entryType.contains("intake") {
            return "Documents gathered"
        }
        if entry.entryType.contains("human_review") {
            return "Human review prepared"
        }
        if entry.entryType.contains("output") {
            return "Final report work"
        }
        return friendlyId(entry.entryType)
    }

    private var phase: String {
        if let workUnitId = entry.workUnitId {
            return friendlyId(workUnitId.replacingOccurrences(of: "document_onboarding.", with: ""))
        }
        return friendlyId(entry.entryType.components(separatedBy: ".").first ?? entry.entryType)
    }

    private var summary: String {
        if entry.entryType.hasSuffix(".team_output") {
            return "The \(phase.lowercased()) team completed its part of the workflow."
        }

        if let text = conciseOutputSummary {
            return text
        }

        return entry.previewText.truncated(to: 220)
    }

    private var conciseOutputSummary: String? {
        let text = entry.previewText
        if text.contains("\"status\": \"pass\"") || text.contains("\"status\":\"pass\"") {
            return "Quality check passed."
        }
        if text.contains("\"status\": \"warning\"") || text.contains("\"status\":\"warning\"") {
            return "Quality check found items that may need attention."
        }
        if text.contains("selectedLanes") || text.contains("confirmedLanes") {
            return "The workflow chose the legal review lanes needed for these documents."
        }
        if text.contains("documentsMetadata") {
            return "The workflow extracted document types, dates, parties, obligations, and sensitivity flags."
        }
        if text.contains("onboardingPacket") {
            return "The workflow gathered the client, matter, and document package."
        }
        return nil
    }

    private var iconName: String {
        if entry.entryType.contains("quality") || entry.entryType.contains("validation") {
            return "checkmark.seal.fill"
        }
        if entry.entryType.contains("routing") {
            return "arrow.triangle.branch"
        }
        if entry.entryType.contains("metadata") {
            return "doc.badge.gearshape"
        }
        if entry.entryType.contains("source") || entry.entryType.contains("intake") {
            return "folder.fill"
        }
        if entry.entryType.contains("human_review") {
            return "person.crop.circle.badge.exclamationmark"
        }
        if entry.entryType.contains("output") {
            return "doc.text.fill"
        }
        return "checkmark.circle.fill"
    }

    private var iconColor: Color {
        if entry.entryType.contains("quality") || entry.previewText.contains("\"status\": \"warning\"") {
            return .orange
        }
        if entry.entryType.contains("human_review") {
            return .blue
        }
        return .green
    }

    private func friendlyId(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}

private struct HumanReviewBlock: View {
    @Environment(AppState.self) private var appState
    let runId: String
    let review: HumanReviewRecord
    @State private var expandedSegmentIds: Set<String> = []
    @State private var approvedSegmentIds: Set<String> = []
    @State private var segmentEditSuggestions: [String: String] = [:]
    @State private var editingSegment: HumanReviewSegment?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(review.title, systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.headline)
                Spacer()
                StatusBadge(text: review.status)
            }

            Text(review.summary)
                .foregroundStyle(.secondary)

            if review.status == "requested" {
                HStack {
                    Button {
                        appState.approveHumanReview(
                            runId: runId,
                            review: review,
                            approvedSegmentIds: approvedSegmentIds
                        )
                    } label: {
                        Label("Finalize Approval", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!allDecisionRequiredSegmentsApproved || hasEditSuggestions)

                    Button {
                        appState.requestHumanReviewChanges(
                            runId: runId,
                            review: review,
                            editSuggestions: segmentEditSuggestions
                        )
                    } label: {
                        Label("Submit Suggested Edits", systemImage: "arrow.uturn.backward.circle")
                    }
                    .disabled(!hasEditSuggestions)

                    Button {
                        approvedSegmentIds = Set(review.segments.filter { $0.status != "optional" }.map(\.id))
                    } label: {
                        Label("Approve Required", systemImage: "checkmark.seal")
                    }

                    Spacer()

                    StatusBadge(text: reviewProgressText)
                }
            } else {
                HStack {
                    StatusBadge(text: reviewProgressText)
                    Text(review.status == "approved" ? "Review has been approved." : "Review decision has been submitted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            ForEach(review.segments) { segment in
                HumanReviewSegmentRow(
                    segment: segment,
                    isExpanded: expandedSegmentIds.contains(segment.id),
                    decision: decisionText(for: segment),
                    editSuggestion: segmentEditSuggestions[segment.id],
                    onToggle: {
                        if expandedSegmentIds.contains(segment.id) {
                            expandedSegmentIds.remove(segment.id)
                        } else {
                            expandedSegmentIds.insert(segment.id)
                        }
                    },
                    onApprove: {
                        approvedSegmentIds.insert(segment.id)
                        segmentEditSuggestions[segment.id] = nil
                    },
                    onSuggestEdit: {
                        editingSegment = segment
                    }
                )
            }
        }
        .padding(12)
        .background(.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(item: $editingSegment) { segment in
            HumanReviewEditSheet(
                segment: segment,
                draft: Binding(
                    get: { segmentEditSuggestions[segment.id] ?? "" },
                    set: { segmentEditSuggestions[segment.id] = $0 }
                ),
                onCancel: {
                    editingSegment = nil
                },
                onSave: {
                    let draft = segmentEditSuggestions[segment.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if draft.isEmpty {
                        segmentEditSuggestions[segment.id] = nil
                    } else {
                        approvedSegmentIds.remove(segment.id)
                    }
                    editingSegment = nil
                }
            )
        }
        .onAppear {
            approvedSegmentIds.formUnion(review.segments.filter { $0.status == "approved" || $0.decision == "approve" }.map(\.id))
        }
    }

    private var requiredSegments: [HumanReviewSegment] {
        review.segments.filter { $0.status != "optional" }
    }

    private var hasEditSuggestions: Bool {
        segmentEditSuggestions.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var allDecisionRequiredSegmentsApproved: Bool {
        requiredSegments.allSatisfy { approvedSegmentIds.contains($0.id) }
    }

    private var reviewProgressText: String {
        if review.status == "approved" {
            return "approved"
        }

        if hasEditSuggestions {
            return "\(segmentEditSuggestions.count) edits"
        }

        let approvedCount = requiredSegments.filter { approvedSegmentIds.contains($0.id) }.count
        if approvedCount == requiredSegments.count, requiredSegments.isEmpty == false {
            return "all approved"
        }

        return "\(approvedCount)/\(requiredSegments.count) approved"
    }

    private func decisionText(for segment: HumanReviewSegment) -> String {
        if segmentEditSuggestions[segment.id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "edit suggested"
        }

        if approvedSegmentIds.contains(segment.id) {
            return "approved"
        }

        return segment.decision ?? segment.status
    }
}

private struct HumanReviewSegmentRow: View {
    let segment: HumanReviewSegment
    let isExpanded: Bool
    let decision: String
    let editSuggestion: String?
    let onToggle: () -> Void
    let onApprove: () -> Void
    let onSuggestEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stateIcon)
                    .foregroundStyle(stateColor)
                    .frame(width: 16)
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Text(segment.label)
                    .font(.callout.weight(.medium))
                Spacer()
                StatusBadge(text: decision)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            if isExpanded {
                MarkdownDetailText(markdown: segment.summary.isEmpty ? "No detail was provided for this review item." : segment.summary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if let editSuggestion, !editSuggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested edit")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(editSuggestion)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Button {
                        onApprove()
                    } label: {
                        Label(isApproved ? "Approved" : "Approve Issue", systemImage: isApproved ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .disabled(isApproved)

                    Button {
                        onSuggestEdit()
                    } label: {
                        Label(isEditSuggested ? "Edit Suggestion" : "Suggest Edit", systemImage: "square.and.pencil")
                    }

                    Spacer()
                }
            } else if !segment.summary.isEmpty {
                Text("Click to inspect, approve, or suggest edits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(stateBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(stateColor.opacity(isPending ? 0.0 : 0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onToggle()
        }
    }

    private var isApproved: Bool {
        decision == "approved"
    }

    private var isEditSuggested: Bool {
        decision == "edit suggested"
    }

    private var isPending: Bool {
        !isApproved && !isEditSuggested
    }

    private var stateIcon: String {
        if isApproved {
            return "checkmark.circle.fill"
        }
        if isEditSuggested {
            return "pencil.circle.fill"
        }
        return "circle"
    }

    private var stateColor: Color {
        if isApproved {
            return .green
        }
        if isEditSuggested {
            return .orange
        }
        return .secondary
    }

    private var stateBackground: Color {
        if isApproved {
            return .green.opacity(0.10)
        }
        if isEditSuggested {
            return .orange.opacity(0.12)
        }
        return Color(nsColor: .textBackgroundColor).opacity(0.75)
    }
}

private struct MarkdownDetailText: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 5) {
                    if let title = section.title {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    ForEach(section.lines, id: \.self) { line in
                        if line.hasPrefix("- ") {
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                Text(Self.plainText(String(line.dropFirst(2))))
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        } else {
                            Text(Self.plainText(line))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var sections: [MarkdownSection] {
        var parsed: [MarkdownSection] = []
        var title: String?
        var lines: [String] = []

        func appendSection() {
            guard title != nil || !lines.isEmpty else { return }
            parsed.append(MarkdownSection(title: title, lines: lines))
        }

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if rawLine.hasPrefix("## ") {
                appendSection()
                title = String(rawLine.dropFirst(3))
                lines = []
            } else if !rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(rawLine)
            }
        }
        appendSection()
        return parsed.isEmpty ? [MarkdownSection(title: nil, lines: [markdown])] : parsed
    }

    private static func plainText(_ value: String) -> String {
        value.replacingOccurrences(of: "`", with: "")
    }

    private struct MarkdownSection: Identifiable {
        let title: String?
        let lines: [String]

        var id: String {
            "\(title ?? "body")-\(lines.joined(separator: "|"))"
        }
    }
}

private struct HumanReviewEditSheet: View {
    let segment: HumanReviewSegment
    @Binding var draft: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Suggest Edit", systemImage: "square.and.pencil")
                    .font(.headline)
                Spacer()
                StatusBadge(text: segment.status)
            }

            Text(segment.label)
                .font(.title3.weight(.semibold))

            Text(segment.summary.isEmpty ? "No detail was provided for this review item." : segment.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Text("Requested change")
                .font(.subheadline.weight(.semibold))

            TextEditor(text: $draft)
                .font(.body)
                .frame(minHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save Suggestion", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 620)
    }
}

private struct OutputPacketBlock: View {
    let packet: WorkflowOutputPacket

    var body: some View {
        if !packet.items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Output Packet")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    StatusBadge(text: "\(packet.fulfilledCount)/\(packet.items.count)")
                }

                ForEach(packet.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: item.isFulfilled ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isFulfilled ? .green : .secondary)
                            Text(item.title)
                                .font(.callout.weight(.medium))
                            Spacer()
                            StatusBadge(text: item.type)
                            if item.required {
                                StatusBadge(text: "required")
                            }
                        }

                        if let output = item.output {
                            Text(summary(for: item, output: output))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        } else if let eventOutput = item.eventOutput {
                            Text(eventSummary(for: item, eventOutput: eventOutput))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        } else {
                            Text(missingSummary(for: item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .background(.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func summary(for item: WorkflowOutputPacketItem, output: OutputEnvelope) -> String {
        switch item.id {
        case "response":
            return "Final user-facing report text is available."
        case "document-onboarding-report":
            return output.content.hasPrefix("/")
                ? "Exportable report file is available."
                : "Exportable report content is available."
        case "documentsMetadata":
            return "Document types, parties, dates, obligations, and sensitivity flags were captured."
        case "routingDecision":
            return "The workflow selected the legal review lanes for this document package."
        case "specialistOutputs":
            return "Specialist findings were captured across the selected legal lanes."
        case "synthesis":
            return "The workflow synthesized specialist findings into a review packet."
        case "reviewPayload":
            return "The attorney review payload was prepared."
        default:
            if output.content.hasPrefix("/") {
                return "File is available."
            }
            return "Output is available."
        }
    }

    private func eventSummary(for item: WorkflowOutputPacketItem, eventOutput: WorkflowEventOutput) -> String {
        if let title = eventOutput.title, !title.isEmpty {
            return "\(title) is available."
        }
        if eventOutput.uri != nil {
            return "Output file is available from the run event stream."
        }
        return summary(for: item, output: OutputEnvelope(id: item.id, type: item.type, title: item.title, content: ""))
    }

    private func missingSummary(for item: WorkflowOutputPacketItem) -> String {
        switch item.type {
        case "json":
            return "Structured data has not been captured for this contract yet."
        case "export_document":
            return "Exportable report has not been generated yet."
        default:
            return "Output has not been generated yet."
        }
    }
}

private struct OutputBlock: View {
    let output: OutputEnvelope
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(output.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(text: output.type)
            }

            if output.content.hasPrefix("/") {
                HStack {
                    Text(output.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    if output.isMarkdownLike {
                        Button {
                            onPreview()
                        } label: {
                            Label("View", systemImage: "doc.text.magnifyingglass")
                        }
                    } else {
                        Button {
                            NSWorkspace.shared.open(URL(filePath: output.content))
                        } label: {
                            Label("Open", systemImage: "arrow.up.forward.app")
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(output.content)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        onPreview()
                    } label: {
                        Label("View", systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
        }
        .padding(12)
        .background(.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct OutputPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let output: OutputEnvelope
    @State private var documentText = ""
    @State private var statusMessage = ""
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label(output.title, systemImage: "doc.richtext")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    export(.docx)
                } label: {
                    Label("Export DOCX", systemImage: "doc")
                }
                .disabled(isExporting || documentText.isEmpty)

                Button {
                    export(.pdf)
                } label: {
                    Label("Export PDF", systemImage: "doc.fill")
                }
                .disabled(isExporting || documentText.isEmpty)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MarkdownPreviewWebView(
                        html: OutputDocumentExporter.htmlDocument(text: documentText, title: output.title)
                    )
                    .frame(minHeight: 520)

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .task {
            documentText = OutputDocumentExporter.loadText(for: output)
        }
    }

    private func export(_ format: OutputDocumentExporter.Format) {
        isExporting = true
        statusMessage = "Exporting \(format.label)..."

        let textSnapshot = documentText
        Task {
            do {
                let url = try OutputDocumentExporter.export(output: output, text: textSnapshot, format: format)
                isExporting = false
                statusMessage = "Exported \(url.lastPathComponent)"
                NSWorkspace.shared.open(url)
            } catch {
                isExporting = false
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}

private struct MarkdownPreviewWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

@MainActor
private enum OutputDocumentExporter {
    enum Format {
        case docx
        case pdf

        var fileExtension: String {
            switch self {
            case .docx:
                "docx"
            case .pdf:
                "pdf"
            }
        }

        var label: String {
            fileExtension.uppercased()
        }
    }

    static func loadText(for output: OutputEnvelope) -> String {
        if output.content.hasPrefix("/"),
           let data = try? Data(contentsOf: URL(filePath: output.content)),
           let text = String(data: data, encoding: .utf8) {
            return text
        }

        if output.content.hasPrefix("/"),
           let markdownURL = companionMarkdownURL(for: URL(filePath: output.content)),
           let data = try? Data(contentsOf: markdownURL),
           let text = String(data: data, encoding: .utf8) {
            return text
        }

        return output.content
    }

    static func export(output: OutputEnvelope, text: String, format: Format) throws -> URL {
        let destination = destinationURL(for: output, format: format)
        switch format {
        case .docx:
            try exportDocx(text: text, title: output.title, destination: destination)
        case .pdf:
            try exportPDF(text: text, destination: destination)
        }
        return destination
    }

    private static func destinationURL(for output: OutputEnvelope, format: Format) -> URL {
        if output.content.hasPrefix("/") {
            let source = output.isMarkdownLike
                ? URL(filePath: output.content)
                : companionMarkdownURL(for: URL(filePath: output.content)) ?? URL(filePath: output.content)
            return source
                .deletingPathExtension()
                .appendingPathExtension(format.fileExtension)
        }

        return FileManager.default.temporaryDirectory
            .appending(path: output.title.sanitizedFilename)
            .deletingPathExtension()
            .appendingPathExtension(format.fileExtension)
    }

    private static func companionMarkdownURL(for url: URL) -> URL? {
        let markdownURL = url.deletingPathExtension().appendingPathExtension("md")
        return FileManager.default.fileExists(atPath: markdownURL.path) ? markdownURL : nil
    }

    private static func exportDocx(text: String, title: String, destination: URL) throws {
        let htmlURL = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).html")
        try htmlDocument(text: text, title: title).write(to: htmlURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/textutil")
        process.arguments = [
            "-convert", "docx",
            "-format", "html",
            "-output", destination.path,
            htmlURL.path
        ]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ExportError.commandFailed("textutil exited with \(process.terminationStatus)")
        }
    }

    private static func exportPDF(text: String, destination: URL) throws {
        let html = htmlDocument(text: text, title: destination.deletingPathExtension().lastPathComponent)
        let htmlData = Data(html.utf8)
        let attributed = try NSAttributedString(
            data: htmlData,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        textView.isEditable = false
        textView.isSelectable = true
        textView.textStorage?.setAttributedString(attributed)
        textView.textContainerInset = NSSize(width: 36, height: 36)

        guard let textContainer = textView.textContainer else {
            throw ExportError.commandFailed("Could not create PDF text container.")
        }

        textContainer.containerSize = NSSize(width: 540, height: CGFloat.greatestFiniteMagnitude)
        textContainer.widthTracksTextView = true
        textView.layoutManager?.ensureLayout(for: textContainer)

        let usedHeight = textView.layoutManager?.usedRect(for: textContainer).height ?? 792
        textView.frame = NSRect(x: 0, y: 0, width: 612, height: max(792, usedHeight + 96))

        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destination

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        if !operation.run() {
            throw ExportError.commandFailed("PDF export was cancelled or failed.")
        }
    }

    static func htmlDocument(text markdown: String, title: String) -> String {
        let body = markdownBodyHTML(markdown)
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>\(title.escapedHTML)</title>
          <style>
            :root { color-scheme: light dark; }
            body {
              margin: 0;
              padding: 34px 42px;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", Helvetica, Arial, sans-serif;
              font-size: 14px;
              line-height: 1.55;
              color: #1f2328;
              background: transparent;
            }
            h1 {
              font-size: 28px;
              line-height: 1.15;
              margin: 0 0 22px;
              padding-bottom: 12px;
              border-bottom: 1px solid #d8dee4;
            }
            h2 {
              font-size: 19px;
              margin: 28px 0 10px;
            }
            h3 {
              font-size: 16px;
              margin: 20px 0 8px;
            }
            p { margin: 0 0 10px; }
            ul, ol { margin: 0 0 14px 24px; padding: 0; }
            li { margin: 4px 0; }
            strong { font-weight: 700; }
            code, pre { font-family: SFMono-Regular, Menlo, monospace; }
            blockquote {
              margin: 12px 0;
              padding: 8px 14px;
              border-left: 3px solid #8c959f;
              color: #57606a;
              background: #f6f8fa;
            }
            table {
              border-collapse: collapse;
              width: 100%;
              margin: 12px 0 18px;
            }
            th, td {
              border: 1px solid #d8dee4;
              padding: 6px 8px;
              text-align: left;
              vertical-align: top;
            }
            th { background: #f6f8fa; font-weight: 700; }
            @media (prefers-color-scheme: dark) {
              body { color: #e6edf3; }
              h1, th, td { border-color: #30363d; }
              blockquote, th { background: #161b22; color: #8b949e; }
            }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func markdownBodyHTML(_ markdown: String) -> String {
        var html: [String] = []
        var paragraph: [String] = []
        var unorderedList: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html.append("<p>\(inlineHTML(paragraph.joined(separator: " ")))</p>")
            paragraph.removeAll()
        }

        func flushList() {
            guard !unorderedList.isEmpty else { return }
            html.append("<ul>")
            html.append(contentsOf: unorderedList.map { "<li>\(inlineHTML($0))</li>" })
            html.append("</ul>")
            unorderedList.removeAll()
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                flushList()
                continue
            }

            if trimmed.hasPrefix("# ") {
                flushParagraph()
                flushList()
                html.append("<h1>\(inlineHTML(String(trimmed.dropFirst(2))))</h1>")
            } else if trimmed.hasPrefix("## ") {
                flushParagraph()
                flushList()
                html.append("<h2>\(inlineHTML(String(trimmed.dropFirst(3))))</h2>")
            } else if trimmed.hasPrefix("### ") {
                flushParagraph()
                flushList()
                html.append("<h3>\(inlineHTML(String(trimmed.dropFirst(4))))</h3>")
            } else if trimmed.hasPrefix("- ") {
                flushParagraph()
                unorderedList.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("> ") {
                flushParagraph()
                flushList()
                html.append("<blockquote>\(inlineHTML(String(trimmed.dropFirst(2))))</blockquote>")
            } else {
                flushList()
                paragraph.append(trimmed)
            }
        }

        flushParagraph()
        flushList()
        return html.joined(separator: "\n")
    }

    private static func inlineHTML(_ value: String) -> String {
        var escaped = value.escapedHTML
        escaped = escaped.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(
            of: #"`(.+?)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )
        return escaped
    }

    enum ExportError: LocalizedError {
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                message
            }
        }
    }
}

private extension String {
    var sanitizedFilename: String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "output" : cleaned
    }

    var escapedHTML: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private extension OutputEnvelope {
    var fileExtension: String {
        if content.hasPrefix("/") {
            return URL(filePath: content).pathExtension.lowercased()
        }
        return ""
    }

    var isMarkdownLike: Bool {
        type.localizedCaseInsensitiveContains("markdown")
            || fileExtension == "md"
            || fileExtension == "markdown"
            || !content.hasPrefix("/")
    }

    var isMarkdownReport: Bool {
        isMarkdownLike && title.localizedCaseInsensitiveContains("report")
    }
}

private enum RunTimeFormatter {
    static func relativeRunTime(for run: WorkflowRunRecord) -> String {
        let timestamp = run.completedAt ?? run.events.last?.timestamp ?? run.startedAt
        guard let date = parse(timestamp) else {
            return timestamp
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func displayDate(_ timestamp: String) -> String {
        guard let date = parse(timestamp) else {
            return timestamp
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func displayEventTime(_ timestamp: String) -> String {
        guard let date = parse(timestamp) else {
            return timestamp
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private static func parse(_ timestamp: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: timestamp) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: timestamp) {
            return date
        }

        return nil
    }
}
