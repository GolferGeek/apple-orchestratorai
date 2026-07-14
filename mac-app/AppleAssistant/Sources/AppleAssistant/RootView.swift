import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            topBar
            Divider()

            VoiceCommandView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(appState)
        .sheet(item: $appState.activeModal) { modal in
            modalView(modal)
                .environment(appState)
                .frame(minWidth: 720, minHeight: 520)
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Text("Apple Assistant")
                .font(.headline)

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
            case .coder:
                CoderEffortsView()
            case .personal:
                PersonalView()
            case .bookWriter, .postWriter, .aiScout, .golfer, .companyGrowth:
                ProfilePlaceholderView(surface: modal)
            }
        }
    }
}
