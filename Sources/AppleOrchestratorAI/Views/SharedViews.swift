import SwiftUI

struct StatusPill: View {
    let status: ReadinessStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var backgroundColor: Color {
        switch status {
        case .ok:
            Color.green.opacity(0.16)
        case .warning:
            Color.yellow.opacity(0.22)
        case .missing, .failed, .needsAttention:
            Color.red.opacity(0.16)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .ok:
            Color.green
        case .warning:
            Color.orange
        case .missing, .failed, .needsAttention:
            Color.red
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}
