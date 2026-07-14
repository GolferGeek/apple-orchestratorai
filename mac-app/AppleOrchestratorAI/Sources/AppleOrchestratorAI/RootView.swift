import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        @Bindable var appState = appState

        HStack(spacing: 0) {
            WorkflowSidebar(selection: $appState.selectedSection)
                .frame(width: 260)

            Divider()

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(appState)
        .sheet(isPresented: $appState.isDocumentOnboardingLaunchPresented) {
            DocumentOnboardingLaunchSheet()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.selectedSection {
        case .runs:
            WorkflowRunsView(
                workflowId: appState.selectedWorkflowId,
                title: selectedWorkflow?.name ?? "Workflow Runs"
            )
        case .workflows:
            WorkflowDefinitionAdminView(workflowId: appState.selectedWorkflowId)
        case .builderAI:
            BuilderAISettingsView()
        case .legalSource:
            LegalSourcePickerView()
        case .pi:
            PiView()
        case .runtime, .hermes:
            PiView()
        }
    }

    private var selectedWorkflow: WorkflowCatalogItem? {
        appState.workflows.first { $0.id == appState.selectedWorkflowId }
    }
}

private struct WorkflowSidebar: View {
    @Environment(AppState.self) private var appState
    @Binding var selection: AppSection
    @State private var infoWorkflow: WorkflowCatalogItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Orchestrator AI")
                    .font(.headline)
                Text("Workflows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    workflowSection
                    adminSection
                }
                .padding(12)
            }

            Divider()

            HStack {
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button {
                    appState.refreshLocalState()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Documents")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if appState.workflows.isEmpty {
                Text("No workflows found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.workflows) { workflow in
                    HStack(spacing: 4) {
                        SidebarRow(
                            title: workflow.name,
                            subtitle: workflow.status,
                            systemImage: iconName(for: workflow),
                            isSelected: selection == .runs && appState.selectedWorkflowId == workflow.id
                        ) {
                            appState.selectedWorkflowId = workflow.id
                            selection = .runs
                        }

                        Button {
                            infoWorkflow = workflow
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Workflow information")
                    }
                }
            }

            Button {
                appState.showDocumentOnboardingLaunch()
                appState.selectedWorkflowId = "document-onboarding"
            } label: {
                Label("New Document Onboarding", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .sheet(item: $infoWorkflow) { workflow in
            WorkflowInfoSheet(workflow: workflow) {
                infoWorkflow = nil
            }
        }
    }

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                Text("Workflows")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if appState.workflows.isEmpty {
                    Text("No workflow agents")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.workflows) { workflow in
                        SidebarRow(
                            title: workflow.name,
                            subtitle: "Agent builder",
                            systemImage: "person.crop.circle.badge.gearshape",
                            isSelected: selection == .workflows && appState.selectedWorkflowId == workflow.id
                        ) {
                            appState.selectedWorkflowId = workflow.id
                            selection = .workflows
                        }
                    }
                }
            }

            SidebarRow(
                title: "Builder AI",
                subtitle: "OpenRouter models",
                systemImage: AppSection.builderAI.symbolName,
                isSelected: selection == .builderAI
            ) {
                selection = .builderAI
            }

            Divider()

            SidebarRow(
                title: "Sources",
                subtitle: "Clients, matters, files",
                systemImage: AppSection.legalSource.symbolName,
                isSelected: selection == .legalSource
            ) {
                selection = .legalSource
            }

            SidebarRow(
                title: "Pi",
                subtitle: "Agent runtime and local models",
                systemImage: AppSection.pi.symbolName,
                isSelected: selection == .pi
            ) {
                selection = .pi
            }
        }
    }

    private func iconName(for workflow: WorkflowCatalogItem) -> String {
        if workflow.id.contains("document") {
            return "doc.text.magnifyingglass"
        }
        return "flowchart"
    }
}

private struct SidebarRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .white : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
