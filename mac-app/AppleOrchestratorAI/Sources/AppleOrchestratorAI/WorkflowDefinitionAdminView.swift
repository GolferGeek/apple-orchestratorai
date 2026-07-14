import SwiftUI

struct WorkflowDefinitionAdminView: View {
    @Environment(AppState.self) private var appState
    let workflowId: String

    @State private var root: WorkflowAgentNode?
    @State private var selectedNodeId = ""
    @State private var status = "Loading workflow agent..."
    @State private var isDirty = false
    @State private var invocationContracts: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if let root {
                HStack(alignment: .top, spacing: 0) {
                    hierarchy(root)
                        .frame(width: 360, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    inspector(root)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                ProgressView(status)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: load)
        .onChange(of: workflowId) { _, _ in load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workflow Agent Builder")
                    .font(.title2.weight(.semibold))
                Text("Define the agent, phases, teams, roles, skills, tools, events, and outputs. Pi executes this structure through the workflow agent.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(status)
                .font(.caption)
                .foregroundStyle(status.hasPrefix("Saved") ? .green : .secondary)
                .lineLimit(1)

            Button {
                load()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Reload workflow agent")

            Button {
                save()
            } label: {
                Label("Save Agent", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isDirty)
        }
        .padding(20)
    }

    private func hierarchy(_ root: WorkflowAgentNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agent Hierarchy")
                    .font(.headline)
                Spacer()
                Text("\(nodeCount(in: root)) nodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                AgentNodeTree(
                    node: root,
                    selectedNodeId: $selectedNodeId,
                    depth: 0
                )
                .padding(.bottom, 12)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func inspector(_ root: WorkflowAgentNode) -> some View {
        if let node = findNode(id: selectedNodeId, in: root) {
            AgentNodeInspector(
                node: node,
                allowedChildKinds: allowedChildren(for: node.kind),
                onChange: { replacement in
                    updateNode(replacement)
                },
                onAddChild: { kind in
                    addChild(kind, to: node.id)
                },
                invocationContract: contractBinding(for: node),
                sharedRoleContract: node.kind == .workflow ? contractBinding(id: "legal-role-base") : nil,
                invocationContext: invocationContext(for: node, in: root),
                sourceDocument: WorkflowImplementationSource.resolve(for: node, repoRoot: appState.repoRoot),
                onDelete: node.kind == .workflow ? nil : {
                    deleteNode(node.id)
                }
            )
        } else {
            EmptyPanel(title: "Select part of the workflow", detail: "Choose a phase, work unit, team, role, skill, tool, or output to edit its purpose and observability contract.")
                .padding(20)
        }
    }

    private func load() {
        let store = WorkflowAgentFileStore()
        if let root = store.load(workflowId: workflowId, repoRoot: appState.repoRoot) {
            let enriched = WorkflowDescriptionEnricher.enrich(root)
            self.root = enriched.node
            let contracts = WorkflowInvocationContractStore().load(url: sourceURL())
            invocationContracts = contracts
            selectedNodeId = enriched.node.id
            if enriched.changed {
                do {
                    try store.save(enriched.node, workflowId: workflowId, repoRoot: appState.repoRoot)
                    try WorkflowInvocationContractStore().save(contracts, url: sourceURL())
                    status = "Expanded workflow descriptions and updated the Markdown source."
                    isDirty = false
                } catch {
                    status = "Expanded descriptions in the builder. Save failed: \(error.localizedDescription)"
                    isDirty = true
                }
            } else {
                status = "Loaded workflow agent source."
                isDirty = false
            }
            return
        }

        guard let workflow = appState.workflows.first(where: { $0.id == workflowId }) else {
            root = nil
            status = "Workflow not found."
            return
        }

        root = WorkflowAgentNode(
            id: workflow.id,
            kind: .workflow,
            name: workflow.name,
            detail: workflow.description,
            model: workflow.defaultLocalModel,
            required: true,
            events: ["workflow.started", "workflow.completed", "workflow.failed"],
            children: []
        )
        selectedNodeId = root?.id ?? ""
        status = "No workflow-agent Markdown exists yet. Add phases in the builder and save the agent source."
        isDirty = false
    }

    private func save() {
        guard let root else { return }
        do {
            try WorkflowAgentFileStore().save(root, workflowId: workflowId, repoRoot: appState.repoRoot)
            try WorkflowInvocationContractStore().save(invocationContracts, url: sourceURL())
            isDirty = false
            status = "Saved workflow agent source."
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    private func updateNode(_ node: WorkflowAgentNode) {
        guard let root else { return }
        self.root = replace(node, in: root)
        isDirty = true
    }

    private func addChild(_ kind: WorkflowAgentNode.Kind, to parentId: String) {
        guard let root else { return }
        let child = WorkflowAgentNode(
            id: "\(kind.rawValue)-\(UUID().uuidString.prefix(8).lowercased())",
            kind: kind,
            name: "New \(kind.label)",
            detail: defaultDetail(for: kind),
            model: nil,
            required: kind != .tool,
            events: defaultEvents(for: kind),
            children: []
        )
        self.root = append(child, to: parentId, in: root)
        selectedNodeId = child.id
        isDirty = true
    }

    private func deleteNode(_ id: String) {
        guard let root else { return }
        self.root = remove(id, from: root)
        selectedNodeId = self.root?.id ?? ""
        isDirty = true
    }

    private func allowedChildren(for kind: WorkflowAgentNode.Kind) -> [WorkflowAgentNode.Kind] {
        switch kind {
        case .workflow: [.phase]
        case .phase: [.subphase, .workUnit]
        case .subphase: [.workUnit]
        case .workUnit: [.workTeam, .skill, .output]
        case .workTeam: [.role]
        case .role: [.skill, .tool, .output]
        case .skill: [.tool, .output]
        case .tool: []
        case .output: []
        }
    }

    private func defaultDetail(for kind: WorkflowAgentNode.Kind) -> String {
        switch kind {
        case .phase: "A bounded workflow phase with an explicit stop condition."
        case .subphase: "A focused section of the parent phase."
        case .workUnit: "A durable unit of work with inputs, outputs, and emitted events."
        case .workTeam: "Named roles collaborate to produce a verified packet."
        case .role: "A bounded specialist responsibility delegated to one agent."
        case .skill: "Reusable instructions the agent invokes for this responsibility."
        case .tool: "A tool the role may call within its permitted boundary."
        case .output: "A durable output required by the workflow contract."
        case .workflow: ""
        }
    }

    private func defaultEvents(for kind: WorkflowAgentNode.Kind) -> [String] {
        switch kind {
        case .phase, .subphase: ["stage.started", "stage.completed", "stage.failed"]
        case .workUnit: ["work_unit.started", "work_unit.completed", "work_unit.failed"]
        case .workTeam: ["team.started", "team.completed", "team.failed"]
        case .role: ["role.started", "role.completed", "role.failed"]
        case .skill: []
        case .tool: ["tool.started", "tool.completed", "tool.failed"]
        case .output: ["output.written", "output.validated", "output.failed"]
        case .workflow: ["workflow.started", "workflow.completed", "workflow.failed"]
        }
    }

    private func findNode(id: String, in node: WorkflowAgentNode) -> WorkflowAgentNode? {
        if node.id == id { return node }
        for child in node.children {
            if let match = findNode(id: id, in: child) { return match }
        }
        return nil
    }

    private func replace(_ replacement: WorkflowAgentNode, in node: WorkflowAgentNode) -> WorkflowAgentNode {
        if node.id == replacement.id { return replacement }
        var next = node
        next.children = node.children.map { replace(replacement, in: $0) }
        return next
    }

    private func append(_ child: WorkflowAgentNode, to parentId: String, in node: WorkflowAgentNode) -> WorkflowAgentNode {
        if node.id == parentId {
            var next = node
            next.children.append(child)
            return next
        }
        var next = node
        next.children = node.children.map { append(child, to: parentId, in: $0) }
        return next
    }

    private func remove(_ id: String, from node: WorkflowAgentNode) -> WorkflowAgentNode {
        var next = node
        next.children = node.children.filter { $0.id != id }.map { remove(id, from: $0) }
        return next
    }

    private func nodeCount(in node: WorkflowAgentNode) -> Int {
        1 + node.children.reduce(0) { $0 + nodeCount(in: $1) }
    }

    private func sourceURL() -> URL? {
        appState.repoRoot?.appending(path: "workflows/legal/\(workflowId).workflow-agent.md")
    }

    private func contractBinding(for node: WorkflowAgentNode) -> Binding<String>? {
        guard node.kind == .workflow || node.kind == .role else { return nil }
        return contractBinding(id: invocationContractKey(for: node))
    }

    private func contractBinding(id key: String) -> Binding<String> {
        return Binding(
            get: { invocationContracts[key] ?? "" },
            set: { value in
                invocationContracts[key] = value
                isDirty = true
            }
        )
    }

    private func invocationContractKey(for node: WorkflowAgentNode) -> String {
        guard node.kind == .role else { return "workflow-operating-contract" }
        let roleId = node.id.components(separatedBy: "::").first ?? node.id
        if invocationContracts[roleId] != nil || node.model == nil { return roleId }
        if roleId.hasSuffix("-specialist") { return "specialist-lane-role" }
        if node.model == "legal-quality-reviewer" { return "quality-reviewer-role" }
        if node.model == "legal-arbitrator" { return "arbitrator-role" }
        return roleId
    }

    private func invocationContext(for node: WorkflowAgentNode, in root: WorkflowAgentNode) -> String? {
        guard node.kind == .skill || node.kind == .tool,
              let path = path(to: node.id, in: root),
              let role = path.reversed().first(where: { $0.kind == .role }) else {
            return nil
        }

        let roleContract = invocationContracts[invocationContractKey(for: role)] ?? "No role invocation contract has been defined."
        let operatingContract = invocationContracts["workflow-operating-contract"] ?? "No workflow operating contract has been defined."
        let sharedContract = invocationContracts["legal-role-base"] ?? "No shared role invocation contract has been defined."
        let workUnit = path.reversed().first(where: { $0.kind == .workUnit })
        let team = path.reversed().first(where: { $0.kind == .workTeam })

        return """
        This \(node.kind.label.lowercased()) is available to \(role.name) (agent: \(role.model ?? "not assigned"))\(team.map { " in \($0.name)" } ?? "")\(workUnit.map { " for \($0.name)" } ?? "").

        Pi composes the following Markdown for that role. The runtime replaces {{RUN_CONTEXT}} and {{PREVIOUS_ROLE_OUTPUTS}} immediately before invocation.

        # Workflow Operating Contract
        \(operatingContract)

        # Shared Role Invocation Contract
        \(sharedContract)

        # Role Invocation Contract
        \(roleContract)
        """
    }

    private func path(to id: String, in node: WorkflowAgentNode) -> [WorkflowAgentNode]? {
        if node.id == id { return [node] }
        for child in node.children {
            if let childPath = path(to: id, in: child) {
                return [node] + childPath
            }
        }
        return nil
    }
}

private struct AgentNodeTree: View {
    let node: WorkflowAgentNode
    @Binding var selectedNodeId: String
    let depth: Int
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                selectedNodeId = node.id
            } label: {
                HStack(spacing: 7) {
                    if !node.children.isEmpty {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption2.weight(.bold))
                            .frame(width: 10)
                            .contentShape(Rectangle())
                            .onTapGesture { expanded.toggle() }
                    } else {
                        Spacer().frame(width: 10)
                    }
                    Image(systemName: node.kind.symbolName)
                        .foregroundStyle(node.kind == .workflow ? Color.accentColor : .secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(node.name)
                            .font(.callout.weight(node.kind == .workflow ? .semibold : .regular))
                            .lineLimit(1)
                        Text(node.kind.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !node.required {
                        Text("optional")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(selectedNodeId == node.id ? Color.accentColor.opacity(0.16) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(node.children) { child in
                    AgentNodeTree(node: child, selectedNodeId: $selectedNodeId, depth: depth + 1)
                        .padding(.leading, 18)
                }
            }
        }
    }
}

private struct AgentNodeInspector: View {
    let node: WorkflowAgentNode
    let allowedChildKinds: [WorkflowAgentNode.Kind]
    let onChange: (WorkflowAgentNode) -> Void
    let onAddChild: (WorkflowAgentNode.Kind) -> Void
    let invocationContract: Binding<String>?
    let sharedRoleContract: Binding<String>?
    let invocationContext: String?
    let sourceDocument: WorkflowImplementationSource?
    let onDelete: (() -> Void)?

    @State private var editing: WorkflowAgentNode
    @State private var eventText = ""
    @State private var showingSource = false

    init(
        node: WorkflowAgentNode,
        allowedChildKinds: [WorkflowAgentNode.Kind],
        onChange: @escaping (WorkflowAgentNode) -> Void,
        onAddChild: @escaping (WorkflowAgentNode.Kind) -> Void,
        invocationContract: Binding<String>?,
        sharedRoleContract: Binding<String>?,
        invocationContext: String?,
        sourceDocument: WorkflowImplementationSource?,
        onDelete: (() -> Void)?
    ) {
        self.node = node
        self.allowedChildKinds = allowedChildKinds
        self.onChange = onChange
        self.onAddChild = onAddChild
        self.invocationContract = invocationContract
        self.sharedRoleContract = sharedRoleContract
        self.invocationContext = invocationContext
        self.sourceDocument = sourceDocument
        self.onDelete = onDelete
        _editing = State(initialValue: node)
        _eventText = State(initialValue: node.events.joined(separator: ", "))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: editing.kind.symbolName)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    Text(editing.kind.label)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                        }
                        .help("Delete \(editing.kind.label.lowercased())")
                    }
                }

                Form {
                    TextField("Name", text: $editing.name)
                    TextField("Identifier", text: $editing.id)
                    TextField("Model", text: Binding(
                        get: { editing.model ?? "" },
                        set: { editing.model = $0.isEmpty ? nil : $0 }
                    ), prompt: Text("Inherit from parent"))
                    Toggle("Required for completion", isOn: $editing.required)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Purpose and boundary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $editing.detail)
                            .font(.body)
                            .frame(minHeight: 90)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Events")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Comma-separated event types", text: $eventText)
                    }
                }
                .formStyle(.grouped)

                if let sourceDocument {
                    HStack(spacing: 10) {
                        Image(systemName: sourceDocument.symbolName)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sourceDocument.title)
                                .font(.headline)
                            Text(sourceDocument.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("View Source") { showingSource = true }
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let invocationContext {
                    DisclosureGroup("Invocation context") {
                        Text("This is the actual workflow context surrounding this capability, not a generic inclusion note.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal) {
                            Text(invocationContext)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 180, maxHeight: 300)
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                if let invocationContract {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(editing.kind == .workflow ? "Workflow operating contract" : "Role invocation contract")
                            .font(.headline)
                        Text("This Markdown is sent to Pi for this workflow or role. Use {{RUN_CONTEXT}} and {{PREVIOUS_ROLE_OUTPUTS}} where live data belongs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: invocationContract)
                            .font(.body)
                            .frame(minHeight: 220)
                    }
                }

                if let sharedRoleContract {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Shared role invocation contract")
                            .font(.headline)
                        Text("Every role receives this Markdown with its own role contract. Use it for shared evidence, escalation, and response rules.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: sharedRoleContract)
                            .font(.body)
                            .frame(minHeight: 220)
                    }
                }

                HStack {
                    Button {
                        editing.events = eventText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        onChange(editing)
                    } label: {
                        Label("Apply Changes", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)

                    if !allowedChildKinds.isEmpty {
                        Menu {
                            ForEach(allowedChildKinds) { kind in
                                Button("Add \(kind.label)") { onAddChild(kind) }
                            }
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }

                if !editing.events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Observability")
                            .font(.headline)
                        FlowLayout(items: editing.events)
                    }
                }
            }
            .padding(20)
        }
        .onChange(of: node) { _, replacement in
            editing = replacement
            eventText = replacement.events.joined(separator: ", ")
        }
        .sheet(isPresented: $showingSource) {
            if let sourceDocument {
                WorkflowSourceDocumentSheet(document: sourceDocument)
            }
        }
    }
}

private struct WorkflowImplementationSource: Identifiable {
    let title: String
    let summary: String
    let sourcePath: String
    let contents: String
    let symbolName: String

    var id: String { sourcePath }

    static func resolve(for node: WorkflowAgentNode, repoRoot: URL?) -> WorkflowImplementationSource? {
        guard let repoRoot else { return nil }
        switch node.kind {
        case .role:
            guard let agentId = node.model else { return nil }
            let url = repoRoot.appending(path: ".pi/agents/\(agentId).md")
            return document(title: "Agent: \(agentId)", url: url, symbolName: "brain.head.profile")
        case .skill:
            let piSkillURL = repoRoot.appending(path: ".pi/skills/\(node.name)/SKILL.md")
            if let source = document(title: "Skill: \(node.name)", url: piSkillURL, symbolName: "wand.and.stars") {
                return source
            }
            return legacySkillDocument(id: node.name, repoRoot: repoRoot)
        case .tool:
            return toolDocument(id: node.name, repoRoot: repoRoot)
        default:
            return nil
        }
    }

    private static func document(title: String, url: URL, symbolName: String) -> WorkflowImplementationSource? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return WorkflowImplementationSource(
            title: title,
            summary: firstMeaningfulLine(in: contents) ?? "Source definition",
            sourcePath: url.path,
            contents: contents,
            symbolName: symbolName
        )
    }

    private static func legacySkillDocument(id: String, repoRoot: URL) -> WorkflowImplementationSource? {
        let skillsRoot = repoRoot.appending(path: "skills", directoryHint: .isDirectory)
        guard let enumerator = FileManager.default.enumerator(at: skillsRoot, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent.hasSuffix(".skill.json") {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  contents.contains("\"id\": \"\(id)\"") else { continue }
            return WorkflowImplementationSource(
                title: "Skill: \(id)",
                summary: firstMeaningfulLine(in: contents) ?? "Legacy skill definition",
                sourcePath: url.path,
                contents: contents,
                symbolName: "wand.and.stars"
            )
        }
        return nil
    }

    private static func toolDocument(id: String, repoRoot: URL) -> WorkflowImplementationSource? {
        let url = repoRoot.appending(path: ".pi/extensions/workflow-tools/index.ts")
        guard let contents = try? String(contentsOf: url, encoding: .utf8),
              let nameRange = contents.range(of: "name: \"\(id)\"") else { return nil }
        let prefix = contents[..<nameRange.lowerBound]
        let start = prefix.range(of: "const ", options: .backwards)?.lowerBound ?? prefix.startIndex
        let remaining = contents[nameRange.upperBound...]
        let end = remaining.range(of: "\nconst ")?.lowerBound ?? contents.endIndex
        let source = String(contents[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        let description = description(in: source) ?? "Pi workflow runtime tool"
        return WorkflowImplementationSource(
            title: "Tool: \(id)",
            summary: description,
            sourcePath: url.path,
            contents: source,
            symbolName: "hammer"
        )
    }

    private static func description(in source: String) -> String? {
        guard let range = source.range(of: "description: \"") else { return nil }
        let remainder = source[range.upperBound...]
        guard let end = remainder.firstIndex(of: "\"") else { return nil }
        return String(remainder[..<end])
    }

    private static func firstMeaningfulLine(in source: String) -> String? {
        source.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                !line.isEmpty && line != "---" && !line.hasPrefix("#") && !line.hasPrefix("{") && !line.hasPrefix("\"")
            }
    }
}

private struct WorkflowSourceDocumentSheet: View {
    let document: WorkflowImplementationSource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: document.symbolName)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                        .font(.title3.weight(.semibold))
                    Text(document.sourcePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(20)

            Divider()

            ScrollView([.horizontal, .vertical]) {
                Text(document.contents)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 760, minHeight: 620)
    }
}

private struct FlowLayout: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

private enum WorkflowDescriptionEnricher {
    static func enrich(_ root: WorkflowAgentNode) -> (node: WorkflowAgentNode, changed: Bool) {
        var changed = false
        let node = enrich(root, ancestors: [], changed: &changed)
        return (node, changed)
    }

    private static func enrich(_ node: WorkflowAgentNode, ancestors: [WorkflowAgentNode], changed: inout Bool) -> WorkflowAgentNode {
        var next = node
        next.children = node.children.map { enrich($0, ancestors: ancestors + [node], changed: &changed) }

        let replacement = enrichedDetail(for: next, ancestors: ancestors)
        if let replacement, replacement != next.detail {
            next.detail = replacement
            changed = true
        }
        return next
    }

    private static func enrichedDetail(for node: WorkflowAgentNode, ancestors: [WorkflowAgentNode]) -> String? {
        let role = ancestors.reversed().first(where: { $0.kind == .role })
        let team = ancestors.reversed().first(where: { $0.kind == .workTeam })
        let workUnit = ancestors.reversed().first(where: { $0.kind == .workUnit })
        let phase = ancestors.reversed().first(where: { $0.kind == .phase })

        switch node.kind {
        case .phase where isGeneric(node.detail):
            return phaseDetail(node.name)
        case .subphase where isGeneric(node.detail):
            return "This subphase is the focused execution path for \(node.name). It groups related work units so the workflow can show progress, preserve handoffs, and stop before the next phase until its required outputs are available."
        case .workUnit where !node.detail.contains("Completion boundary:"):
            return "\(node.detail) Completion boundary: this unit is complete only after its required team packet and named outputs are persisted, observable, and usable by the next workflow step."
        case .workTeam where !node.detail.contains("Team boundary:"):
            return "\(node.detail) Team boundary: each role performs only its assigned responsibility; the team returns one traceable packet that preserves role outputs, warnings, disagreements, and any escalation."
        case .role where !node.detail.contains("Role boundary:"):
            let unitName = workUnit?.name ?? "this work unit"
            let teamName = team?.name ?? "its work team"
            return "\(node.detail) Role boundary: within \(teamName), this role owns only its contribution to \(unitName), uses the listed capabilities, returns an evidence-backed role packet, and escalates unresolved legal judgment rather than continuing into another responsibility."
        case .skill where isGeneric(node.detail):
            let owner = role?.name ?? "the assigned role"
            let unitName = workUnit?.name ?? "this work unit"
            return "Gives \(owner) the reusable \(node.name) capability while performing \(unitName). The skill is available only within that role's invocation contract; it does not authorize work in later phases or outside the role's stated boundary."
        case .tool where isGeneric(node.detail):
            let owner = role?.name ?? "the assigned role"
            return "Allows \(owner) to call \(node.name) for \(toolPurpose(node.name)). The call and its result are recorded in the workflow event stream; the tool does not grant authority to change client data, workflow structure, or human-review decisions."
        case .output where isGeneric(node.detail):
            let unitName = workUnit?.name ?? phase?.name ?? "the current workflow step"
            return "Persists \(node.name) as the durable handoff from \(unitName). It must contain the required structured packet or artifact, usable source references where applicable, and visible warnings or human-review flags before downstream work may rely on it."
        default:
            return nil
        }
    }

    private static func isGeneric(_ detail: String) -> Bool {
        detail == "sequential workflow phase."
            || detail == "fanout workflow phase."
            || detail == "human-gated workflow phase."
            || detail.hasPrefix("Graph: ")
            || detail.hasPrefix("Reusable skill used by ")
            || detail == "Permitted runtime tool."
            || detail == "Durable workflow output."
    }

    private static func phaseDetail(_ name: String) -> String {
        switch name {
        case "Metadata":
            return "Establishes a trustworthy document record before legal interpretation begins: resolve the client and matter, stage approved local files, extract text, and capture document metadata with source references and extraction limits. This phase stops when downstream reviewers have a usable, traceable document packet."
        case "Classify":
            return "Turns the verified document packet into a legal work-allocation decision. It identifies the specialist lanes that evidence supports, records excluded alternatives, and escalates weak classification or material ambiguity instead of silently narrowing review."
        case "Specialists":
            return "Runs the selected legal specialist lanes against the same verified document record. Findings remain separate by lane, then receive quality review and, where needed, arbitration so the workflow preserves disagreement rather than averaging it away."
        case "Synthesis":
            return "Combines verified specialist packets into a decision-ready synthesis: document facts, supported findings, conflicts, confidence, open questions, recommended actions, and the precise issues that require attorney review."
        case "Human Review":
            return "Pauses finalization for discrete attorney decisions. The workflow creates reviewable segments with evidence and consequences, waits for a recorded decision, and carries edits or rejections forward as explicit instructions."
        case "Report":
            return "Produces and validates the final approved output only after required human review is complete. It renders the report and artifacts, checks release requirements, and records the final workflow response for the user."
        default:
            return "Groups a bounded part of the workflow with an explicit purpose, completion condition, observable events, and durable handoff to the next phase."
        }
    }

    private static func toolPurpose(_ tool: String) -> String {
        return switch tool {
        case "workflow_resolve_client_matter": "resolving the launch client and matter to stable local records"
        case "workflow_list_source_options": "discovering approved document sources available for the selected matter"
        case "workflow_resolve_documents": "resolving the user-selected document paths and source references"
        case "workflow_extract_text": "extracting text and recording extraction limitations from approved documents"
        case "workflow_request_human_review": "creating a persisted, segmented attorney-review request"
        case "workflow_wait_for_human_review": "waiting for the recorded reviewer decision before finalization"
        case "workflow_write_artifact": "writing a validated report artifact to the run's external artifact store"
        case "workflow_structured_output": "persisting the final structured response for display and downstream use"
        default: "the bounded capability described by its source definition"
        }
    }
}

struct WorkflowAgentFileStore {
    private let markerPrefix = "<!-- ao-node "

    func load(workflowId: String, repoRoot: URL?) -> WorkflowAgentNode? {
        guard let url = sourceURL(workflowId: workflowId, repoRoot: repoRoot) else {
            return nil
        }
        return load(url: url)
    }

    func load(url: URL) -> WorkflowAgentNode? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var flat: [(depth: Int, node: WorkflowAgentNode)] = []
        for (index, line) in lines.enumerated() where line.trimmingCharacters(in: .whitespaces).hasPrefix(markerPrefix) {
            guard index > 0, let node = decodeNode(from: line) else { continue }
            let prior = lines[index - 1]
            let leadingSpaces = prior.prefix { $0 == " " }.count
            flat.append((max(0, leadingSpaces / 2), node))
        }
        guard !flat.isEmpty else { return nil }
        var cursor = 0
        var identifiers: [String: Int] = [:]
        return uniquify(buildTree(from: flat, cursor: &cursor, at: flat[0].depth), identifiers: &identifiers)
    }

    func save(_ root: WorkflowAgentNode, workflowId: String, repoRoot: URL?) throws {
        guard let url = sourceURL(workflowId: workflowId, repoRoot: repoRoot) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let productSection = WorkflowProductBriefStore().preservedSection(in: existing)
        let text = markdown(root: root) + (productSection.map { "\n\n\($0)" } ?? "") + "\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func agentURLs(repoRoot: URL?) -> [URL] {
        guard let repoRoot else { return [] }
        let workflowsRoot = repoRoot.appending(path: "workflows", directoryHint: .isDirectory)
        guard let enumerator = FileManager.default.enumerator(at: workflowsRoot, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.lastPathComponent.hasSuffix(".workflow-agent.md") }
            .sorted { $0.path < $1.path }
    }

    private func sourceURL(workflowId: String, repoRoot: URL?) -> URL? {
        guard let repoRoot else { return nil }
        let directory = repoRoot.appending(path: "workflows/legal", directoryHint: .isDirectory)
        return directory.appending(path: "\(workflowId).workflow-agent.md")
    }

    private func markdown(root: WorkflowAgentNode) -> String {
        let defaultModel = root.model ?? "inherit"
        var lines = [
            "---",
            "kind: apple-orchestrator-workflow-agent",
            "id: \(root.id)",
            "name: \(root.name)",
            "default_model: \(defaultModel)",
            "---",
            "",
            "# \(root.name)",
            "",
            root.detail
        ]
        appendMarkdown(node: root, depth: 0, lines: &lines)
        return lines.joined(separator: "\n")
    }

    private func appendMarkdown(node: WorkflowAgentNode, depth: Int, lines: inout [String]) {
        let indent = String(repeating: "  ", count: depth)
        lines.append("\(indent)- \(node.kind.label): \(node.name)")
        lines.append("\(indent)  \(encodeNode(node))")
        if !node.detail.isEmpty { lines.append("\(indent)  > \(node.detail)") }
        for child in node.children {
            appendMarkdown(node: child, depth: depth + 1, lines: &lines)
        }
    }

    private func encodeNode(_ node: WorkflowAgentNode) -> String {
        let eventValue = node.events.joined(separator: "\u{1F}")
        let model = node.model ?? ""
        let required = node.required ? "1" : "0"
        return "\(markerPrefix)kind=\(node.kind.rawValue) id=\(encode(node.id)) name=\(encode(node.name)) detail=\(encode(node.detail)) model=\(encode(model)) required=\(required) events=\(encode(eventValue)) -->"
    }

    private func decodeNode(from line: String) -> WorkflowAgentNode? {
        let content = line.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: markerPrefix, with: "")
            .replacingOccurrences(of: " -->", with: "")
        let values = Dictionary(uniqueKeysWithValues: content.split(separator: " ").compactMap { part -> (String, String)? in
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            return pair.count == 2 ? (pair[0], pair[1]) : nil
        })
        guard let kindValue = values["kind"], let kind = WorkflowAgentNode.Kind(rawValue: kindValue), let id = values["id"].flatMap(decode), let name = values["name"].flatMap(decode) else {
            return nil
        }
        let detail = values["detail"].flatMap(decode) ?? ""
        let model = values["model"].flatMap(decode).flatMap { $0.isEmpty ? nil : $0 }
        let events = (values["events"].flatMap(decode) ?? "").split(separator: "\u{1F}").map(String.init)
        return WorkflowAgentNode(id: id, kind: kind, name: name, detail: detail, model: model, required: values["required"] != "0", events: events, children: [])
    }

    private func buildTree(from flat: [(depth: Int, node: WorkflowAgentNode)], cursor: inout Int, at depth: Int) -> WorkflowAgentNode {
        var node = flat[cursor].node
        cursor += 1
        while cursor < flat.count, flat[cursor].depth > depth {
            node.children.append(buildTree(from: flat, cursor: &cursor, at: flat[cursor].depth))
        }
        return node
    }

    private func uniquify(_ node: WorkflowAgentNode, identifiers: inout [String: Int]) -> WorkflowAgentNode {
        var next = node
        let count = identifiers[node.id, default: 0]
        identifiers[node.id] = count + 1
        if count > 0 { next.id = "\(node.id)::\(count + 1)" }
        next.children = node.children.map { uniquify($0, identifiers: &identifiers) }
        return next
    }

    private func encode(_ value: String) -> String {
        Data(value.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "_")
    }

    private func decode(_ value: String) -> String? {
        let padding = String(repeating: "=", count: (4 - value.count % 4) % 4)
        guard let data = Data(base64Encoded: value.replacingOccurrences(of: "_", with: "=") + padding) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
