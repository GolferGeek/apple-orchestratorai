import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            topBar(selection: $appState.selectedSection)
            Divider()

            Group {
                switch appState.selectedSection {
                case .voice:
                    VoiceCommandView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(appState)
        .sheet(item: $appState.activeModal) { modal in
            modalView(modal)
                .environment(appState)
                .frame(minWidth: 780, minHeight: 540)
        }
    }

    private func topBar(selection: Binding<AppSection>) -> some View {
        HStack(spacing: 14) {
            Text("Apple Orchestrator AI")
                .font(.headline)

            Picker("Surface", selection: selection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)

            Spacer()

            Text("Voice-first")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func modalView(_ modal: ModalSurface) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label(modal.title, systemImage: modal.symbolName)
                    .font(.headline)

                Spacer()

                Button {
                    appState.activeModal = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            switch modal {
            case .hermes:
                HermesView()
            case .pi:
                PiView()
            case .runtime:
                RuntimeView()
            case .workflows:
                WorkflowCatalogView()
            case .runs:
                WorkflowRunsView()
            }
        }
    }
}
