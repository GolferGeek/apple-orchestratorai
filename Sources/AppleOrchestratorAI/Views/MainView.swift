import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            Picker("Surface", selection: $appState.selectedSurface) {
                ForEach(AppSurface.allCases) { surface in
                    Text(surface.rawValue).tag(surface)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch appState.selectedSurface {
                case .status:
                    StatusView()
                case .workflows:
                    WorkflowsView()
                case .runtime:
                    RuntimeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PromptBarView()
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
