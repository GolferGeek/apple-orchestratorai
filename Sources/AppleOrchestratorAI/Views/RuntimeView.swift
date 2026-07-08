import SwiftUI

struct RuntimeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let hermesStatus = appState.hermesStatus {
                    RuntimeSection(title: "Hermes API") {
                        RuntimeRow(
                            title: "Gateway",
                            subtitle: hermesStatus.health.displayName,
                            detail: "\(hermesStatus.baseURL) - \(hermesStatus.health.detail)",
                            status: hermesStatus.health.readinessStatus
                        )

                        if let capabilities = hermesStatus.capabilities {
                            RuntimeRow(title: capabilities.path, subtitle: capabilities.status.displayName, detail: capabilities.detail, status: capabilities.status)
                        }
                        if let models = hermesStatus.models {
                            RuntimeRow(title: models.path, subtitle: models.status.displayName, detail: models.detail, status: models.status)
                        }
                        if let skills = hermesStatus.skills {
                            RuntimeRow(title: skills.path, subtitle: skills.status.displayName, detail: skills.detail, status: skills.status)
                        }
                        if let toolsets = hermesStatus.toolsets {
                            RuntimeRow(title: toolsets.path, subtitle: toolsets.status.displayName, detail: toolsets.detail, status: toolsets.status)
                        }
                    }
                } else {
                    RuntimeSection(title: "Hermes API") {
                        RuntimeRow(title: "Gateway", subtitle: "Not Checked", detail: "Refresh to check the local Hermes API.", status: .warning)
                    }
                }

                if let ollamaStatus = appState.ollamaStatus {
                    RuntimeSection(title: "Ollama") {
                        RuntimeRow(
                            title: "Shared Runtime",
                            subtitle: ollamaStatus.sharedEndpoint.status.displayName,
                            detail: "\(ollamaStatus.sharedEndpoint.baseURL) - \(ollamaStatus.sharedEndpoint.detail)",
                            status: ollamaStatus.sharedEndpoint.status
                        )
                        RuntimeRow(
                            title: "System Runtime",
                            subtitle: ollamaStatus.systemEndpoint.status.displayName,
                            detail: "\(ollamaStatus.systemEndpoint.baseURL) - \(ollamaStatus.systemEndpoint.detail)",
                            status: ollamaStatus.systemEndpoint.status
                        )
                        RuntimeRow(
                            title: "Default Model",
                            subtitle: "Hermes",
                            detail: ollamaStatus.selectedDefaultModel,
                            status: .ok
                        )
                    }

                    RuntimeSection(title: "Installed Apple-Optimized Models") {
                        if ollamaStatus.optimizedModels.isEmpty {
                            RuntimeRow(title: "Optimized Models", subtitle: "Missing", detail: "No expected Qwen NVFP4 or Gemma MLX models were reported by 127.0.0.1:11435.", status: .warning)
                        } else {
                            ForEach(ollamaStatus.optimizedModels) { model in
                                RuntimeRow(title: model.name, subtitle: model.size, detail: model.modified, status: .ok)
                            }
                        }
                    }
                } else {
                    RuntimeSection(title: "Ollama") {
                        RuntimeRow(title: "Shared Runtime", subtitle: "Not Checked", detail: "Refresh to check Ollama endpoints.", status: .warning)
                    }
                }

                if !appState.recentRuns.isEmpty {
                    RuntimeSection(title: "Recent Runs") {
                        ForEach(appState.recentRuns) { run in
                            RuntimeRow(
                                title: run.id,
                                subtitle: run.status,
                                detail: "\(run.prompt)\n\(run.detail)",
                                status: run.status == "failed" ? .failed : .ok
                            )
                        }
                    }
                }

                if let manifest = appState.manifest {
                    RuntimeSection(title: "Runtimes") {
                        ForEach(manifest.runtimes) { runtime in
                            RuntimeRow(
                                title: runtime.id,
                                subtitle: runtime.required ? "Required" : "Optional",
                                detail: runtime.responsibilities.joined(separator: ", "),
                                status: .ok
                            )
                        }
                    }

                    RuntimeSection(title: "Profiles") {
                        ForEach(manifest.profiles) { profile in
                            RuntimeRow(
                                title: profile.id,
                                subtitle: profile.required ? "Required" : "Optional",
                                detail: profile.responsibilities.joined(separator: ", "),
                                status: .ok
                            )
                        }
                    }

                    RuntimeSection(title: "Roots") {
                        ForEach(manifest.workflowRoots, id: \.self) { root in
                            RuntimeRow(title: root, subtitle: "Workflow root", detail: "", status: .ok)
                        }
                        ForEach(manifest.skillRoots, id: \.self) { root in
                            RuntimeRow(title: root, subtitle: "Skill root", detail: "", status: .ok)
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "Runtime manifest unavailable",
                        detail: "The app could not load runtime/runtime-manifest.json."
                    )
                }
            }
            .padding(20)
        }
    }
}

struct RuntimeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(spacing: 8) {
                content
            }
        }
    }
}

struct RuntimeRow: View {
    let title: String
    let subtitle: String
    let detail: String
    let status: ReadinessStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                Spacer()
                StatusPill(status: status)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !detail.isEmpty {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
