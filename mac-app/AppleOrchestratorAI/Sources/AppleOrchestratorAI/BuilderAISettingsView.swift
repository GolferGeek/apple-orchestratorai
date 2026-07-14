import SwiftUI

struct BuilderAISettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingKey = false
    @State private var showAllModels = false

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Builder AI")
                        .font(.title2.weight(.semibold))
                    Text("Use OpenRouter only to help design or revise a workflow-agent hierarchy. Builder prompts never include client documents or workflow-run outputs.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                GroupBox("OpenRouter Connection") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if showingKey {
                                TextField("OpenRouter API key", text: $appState.openRouterAPIKey)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("OpenRouter API key", text: $appState.openRouterAPIKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Button {
                                showingKey.toggle()
                            } label: {
                                Image(systemName: showingKey ? "eye.slash" : "eye")
                            }
                            .help(showingKey ? "Hide key" : "Show key")
                            Button("Save Key") { appState.saveOpenRouterAPIKey() }
                        }

                        HStack {
                            Button {
                                appState.loadOpenRouterModels()
                            } label: {
                                Label("Load Current Models", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            Text(appState.openRouterStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Builder Model") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Show every available OpenRouter model", isOn: $showAllModels)
                        Picker("Model", selection: $appState.selectedBuilderModelId) {
                            ForEach(visibleModels) { model in
                                Text(model.name.isEmpty ? model.id : "\(model.name) (\(model.id))")
                                    .tag(model.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 660, alignment: .leading)

                        Text("The model is used for workflow design, clarification, and node-level updates. Execution model policy stays in the workflow agent itself.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Recommended Starting Points") {
                    VStack(alignment: .leading, spacing: 8) {
                        BuilderModelRecommendation(tier: "Economical", models: "Qwen 3.6 Flash, DeepSeek V4 Flash")
                        BuilderModelRecommendation(tier: "Balanced", models: "Qwen 3.7 Plus, Gemini 3.1 Flash Lite, DeepSeek V4 Pro")
                        BuilderModelRecommendation(tier: "Premium", models: "Claude Sonnet 5, GPT-5.6 Terra, Gemini 3.1 Pro")
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var visibleModels: [OpenRouterModel] {
        let fallback = appState.recommendedBuilderModels.map { OpenRouterModel(id: $0, name: $0, contextLength: nil, pricing: nil, architecture: nil) }
        let models = appState.openRouterModels.isEmpty ? fallback : appState.openRouterModels
        if showAllModels { return models }
        let recommended = models.filter { appState.recommendedBuilderModels.contains($0.id) }
        return recommended.isEmpty ? models.prefix(12).map { $0 } : recommended
    }
}

private struct BuilderModelRecommendation: View {
    let tier: String
    let models: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(tier)
                .font(.callout.weight(.semibold))
                .frame(width: 86, alignment: .leading)
            Text(models)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
