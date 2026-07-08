import SwiftUI

struct StatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(appState.readiness.checks) { check in
                    ReadinessCard(check: check)
                }
            }
            .padding(20)
        }
    }
}

struct ReadinessCard: View {
    let check: ReadinessCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(check.label)
                    .font(.headline)
                Spacer()
                StatusPill(status: check.status)
            }

            Text(check.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
