import SwiftUI

struct WorkflowInfoSheet: View {
    @Environment(AppState.self) private var appState
    let workflow: WorkflowCatalogItem
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.name)
                        .font(.title2.weight(.semibold))
                    Text("Workflow information")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: onDismiss)
            }
            .padding(20)

            Divider()

            TabView {
                WorkflowInfoMarkdownTab(markdown: workflow.brief.overview)
                    .tabItem { Label("Overview", systemImage: "rectangle.text.magnifyingglass") }

                WorkflowInfoMarkdownTab(markdown: workflow.brief.benefits)
                    .tabItem { Label("Benefits", systemImage: "sparkles") }

                WorkflowTestCasesTab(workflow: workflow)
                    .tabItem { Label("Test Cases", systemImage: "checklist") }

                WorkflowInfoMarkdownTab(markdown: workflow.brief.userGuide)
                    .tabItem { Label("User Guide", systemImage: "book") }

                WorkflowAdminTab(workflow: workflow)
                    .tabItem { Label("Admin", systemImage: "slider.horizontal.3") }
            }
            .padding(.horizontal, 12)
        }
        .frame(minWidth: 760, minHeight: 570)
    }
}

private struct WorkflowInfoMarkdownTab: View {
    let markdown: String

    var body: some View {
        ScrollView {
            ProductMarkdownView(markdown: markdown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }
}

private struct WorkflowTestCasesTab: View {
    @Environment(AppState.self) private var appState
    let workflow: WorkflowCatalogItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Runnable Test Cases")
                    .font(.title3.weight(.semibold))
                Text("Each case states its fixture, expected workflow behavior, and review contract. Test files remain outside the app's run-state database.")
                    .foregroundStyle(.secondary)

                if workflow.brief.testCases.isEmpty {
                    EmptyPanel(title: "No test cases", detail: "Add test cases to the Workflow Product section in the workflow-agent Markdown.")
                } else {
                    ForEach(workflow.brief.testCases) { testCase in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(testCase.name)
                                        .font(.headline)
                                    Text(testCase.goal)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(text: testCase.runnable ? "runnable" : "planned")
                            }

                            LabeledContent("Fixture", value: testCase.fixture)
                            LabeledContent("Expected", value: testCase.expected)
                            LabeledContent("Review", value: testCase.review)

                            HStack {
                                Button {
                                    appState.runWorkflowTestCase(testCase, workflowId: workflow.id)
                                } label: {
                                    Label("Run This Case", systemImage: "play.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!testCase.runnable)

                                if !testCase.runnable {
                                    Text("Fixture contract is defined; runner is not wired yet.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}

private struct WorkflowAdminTab: View {
    @Environment(AppState.self) private var appState
    let workflow: WorkflowCatalogItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Workflow Administration")
                    .font(.title3.weight(.semibold))
                ProductMarkdownView(markdown: workflow.brief.adminNotes)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current definition")
                        .font(.headline)
                    LabeledContent("Default model", value: workflow.defaultLocalModel)
                    LabeledContent("Human interaction", value: workflow.humanInteraction)
                    LabeledContent("Outputs", value: workflow.outputContracts.map(\.id).joined(separator: ", "))
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    appState.selectedWorkflowId = workflow.id
                    appState.selectedSection = .workflows
                } label: {
                    Label("Open Workflow Agent Builder", systemImage: "person.crop.circle.badge.gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}

private struct ProductMarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lines, id: \.offset) { _, line in
                if line.hasPrefix("- ") {
                    HStack(alignment: .top, spacing: 7) {
                        Text("•")
                        Text(clean(String(line.dropFirst(2))))
                    }
                    .foregroundStyle(.secondary)
                } else if let item = numberedItem(line) {
                    HStack(alignment: .top, spacing: 7) {
                        Text(item.number)
                            .foregroundStyle(.secondary)
                        Text(clean(item.text))
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text(clean(line))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var lines: [(offset: Int, line: String)] {
        markdown.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .enumerated()
            .map { ($0.offset, $0.element) }
    }

    private func clean(_ value: String) -> String {
        value.replacingOccurrences(of: "`", with: "")
    }

    private func numberedItem(_ value: String) -> (number: String, text: String)? {
        guard let dot = value.firstIndex(of: "."), value[..<dot].allSatisfy(\.isNumber) else { return nil }
        return (String(value[...dot]), String(value[value.index(after: dot)...]).trimmingCharacters(in: .whitespaces))
    }
}
