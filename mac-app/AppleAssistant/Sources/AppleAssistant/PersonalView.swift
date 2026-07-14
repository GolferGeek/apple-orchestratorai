import SwiftUI

struct PersonalView: View {
    @Environment(AppState.self) private var appState
    @State private var journalText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal")
                .font(.title2.weight(.semibold))
            Text("Calendar, Reminders, and Day One are local personal integrations.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    appState.requestCalendarAccess()
                } label: {
                    Label("Allow Calendar", systemImage: "calendar.badge.checkmark")
                }

                Button {
                    appState.showTodayCalendar()
                } label: {
                    Label("Today", systemImage: "calendar")
                }

                Button {
                    appState.requestReminderAccess()
                } label: {
                    Label("Allow Reminders", systemImage: "checklist")
                }

                Button {
                    appState.showReminders()
                } label: {
                    Label("Reminders", systemImage: "list.bullet")
                }
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 8) {
                Text("Day One")
                    .font(.headline)
                TextField("Journal entry text", text: $journalText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)

                Button {
                    appState.createDayOneEntry(journalText)
                    journalText = ""
                } label: {
                    Label("Write To Day One", systemImage: "book.closed")
                }
            }

            Text(appState.personalOutput)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .background(.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
    }
}
