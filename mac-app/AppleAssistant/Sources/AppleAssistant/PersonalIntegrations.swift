import EventKit
import Foundation

@MainActor
final class PersonalIntegrations {
    private let eventStore = EKEventStore()

    func requestCalendarAccess() async -> String {
        do {
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                return granted ? "Calendar access granted." : "Calendar access was not granted."
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                return granted ? "Calendar access granted." : "Calendar access was not granted."
            }
        } catch {
            return "Calendar access failed: \(error.localizedDescription)"
        }
    }

    func requestReminderAccess() async -> String {
        do {
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToReminders()
                return granted ? "Reminders access granted." : "Reminders access was not granted."
            } else {
                let granted = try await eventStore.requestAccess(to: .reminder)
                return granted ? "Reminders access granted." : "Reminders access was not granted."
            }
        } catch {
            return "Reminders access failed: \(error.localizedDescription)"
        }
    }

    func calendarSummaryForToday() -> String {
        let calendars = eventStore.calendars(for: .event)
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        guard !events.isEmpty else {
            return "There are no calendar events for today."
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        let lines = events.prefix(8).map { event in
            "\(formatter.string(from: event.startDate)): \(event.title ?? "Untitled event")"
        }
        return "Today's calendar:\n" + lines.joined(separator: "\n")
    }

    func reminderSummary() async -> String {
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let reminders = (reminders ?? []).sorted {
                    ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture)
                }

                guard !reminders.isEmpty else {
                    continuation.resume(returning: "There are no incomplete reminders.")
                    return
                }

                let lines = reminders.prefix(8).map { reminder in
                    reminder.title ?? "Untitled reminder"
                }
                continuation.resume(returning: "Open reminders:\n" + lines.joined(separator: "\n"))
            }
        }
    }

    func createDayOneEntry(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Tell me what to write into Day One."
        }

        guard let cli = findDayOneCLI() else {
            return "Day One CLI was not found. In Day One, install command line tools, then try again."
        }

        return await Task.detached {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cli)
                process.arguments = ["new"]

                let input = Pipe()
                let output = Pipe()
                process.standardInput = input
                process.standardOutput = output
                process.standardError = output

                try process.run()
                input.fileHandleForWriting.write(Data(trimmed.utf8))
                try? input.fileHandleForWriting.close()
                process.waitUntilExit()

                let data = output.fileHandleForReading.readDataToEndOfFile()
                let response = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationStatus == 0 {
                    return response.isEmpty ? "Day One entry created." : "Day One entry created. \(response)"
                }
                return response.isEmpty ? "Day One CLI failed." : "Day One CLI failed: \(response)"
            } catch {
                return "Day One CLI failed: \(error.localizedDescription)"
            }
        }.value
    }

    private func findDayOneCLI() -> String? {
        let candidates = [
            "/usr/local/bin/dayone",
            "/opt/homebrew/bin/dayone",
            "/usr/local/bin/dayone2",
            "/opt/homebrew/bin/dayone2"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return nil
    }
}
