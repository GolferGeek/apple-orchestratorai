import SwiftUI

struct StatusBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .separatorColor).opacity(0.35))
            .clipShape(Capsule())
    }
}

struct EmptyPanel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct GenericListBlock: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Text(item)
                }
            }
        }
    }
}

struct GenericTimelineBlock: View {
    let title: String
    let stages: [WorkflowStageRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(stages) { stage in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: stage.status == "completed" ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(stage.status == "completed" ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(stage.name)
                                .font(.callout.weight(.medium))
                            Spacer()
                            Text(stage.status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(stage.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
