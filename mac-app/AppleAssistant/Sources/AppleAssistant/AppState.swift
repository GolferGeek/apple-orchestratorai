import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var selectedSection: AppSection = .voice
    var activeModal: ModalSurface?
    var recentModalSurfaces: [ModalSurface] = []
    var repoRoot: URL?
    var surface: CoderEffortsSurface?
    var statusMessage = "Ready"
    var personalOutput = "Calendar, Reminders, and Day One are ready to connect."
    var voiceCommand = ""
    var voicePrompt = "Tell me what you want to do. Try: what is on my calendar, what reminders are open, write journal, show personal, or help."
    var voiceLines: [String] = [
        "App: Tell me what you want to do."
    ]
    var isListening = false
    var speechStatus = "Microphone idle."

    private let speechSynthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SpeechCommandRecognizer()
    private let personalIntegrations = PersonalIntegrations()

    init() {
        repoRoot = RepositoryLocator.findRepoRoot()
        reloadEfforts()
    }

    func reloadEfforts() {
        guard let repoRoot else {
            statusMessage = "Could not locate repository root."
            return
        }

        do {
            let result = try Shell.run(
                "/usr/bin/env",
                [
                    "python3",
                    "scripts/render-coder-efforts-surface.py",
                    "--app-id",
                    "apple-orchestratorai",
                    "--repo-root",
                    repoRoot.path
                ],
                cwd: repoRoot
            )

            guard result.exitCode == 0 else {
                statusMessage = result.output
                return
            }

            let data = Data(result.output.utf8)
            surface = try JSONDecoder().decode(CoderEffortsSurface.self, from: data)
            statusMessage = "Loaded coder efforts."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func submitVoiceCommand() {
        let command = voiceCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            speak("Tell me what you want to do.")
            return
        }

        voiceLines.append("You: \(command)")
        voiceCommand = ""
        handleVoiceCommand(command)
    }

    func speakPrompt() {
        speak(voicePrompt)
    }

    func runQuickCommand(_ command: String) {
        voiceCommand = command
        submitVoiceCommand()
    }

    func toggleListening() {
        if isListening {
            speechRecognizer.stop()
            isListening = false
            speechStatus = "Microphone idle."
            return
        }

        Task {
            await speechRecognizer.start { [weak self] transcript, isFinal in
                guard let self else { return }
                self.voiceCommand = transcript
                if isFinal {
                    self.submitVoiceCommand()
                    self.isListening = false
                    self.speechStatus = "Microphone idle."
                }
            } onStatus: { [weak self] status in
                guard let self else { return }
                self.speechStatus = status
                self.isListening = self.speechRecognizer.isListening
            }
            isListening = speechRecognizer.isListening
        }
    }

    func openModal(_ modal: ModalSurface) {
        if !recentModalSurfaces.contains(where: { $0 == modal }) {
            recentModalSurfaces.append(modal)
        }
        activeModal = modal
    }

    func requestCalendarAccess() {
        Task {
            let result = await personalIntegrations.requestCalendarAccess()
            personalOutput = result
            respond(result)
        }
    }

    func requestReminderAccess() {
        Task {
            let result = await personalIntegrations.requestReminderAccess()
            personalOutput = result
            respond(result)
        }
    }

    func showTodayCalendar() {
        let result = personalIntegrations.calendarSummaryForToday()
        personalOutput = result
        respond(result)
    }

    func showReminders() {
        Task {
            let result = await personalIntegrations.reminderSummary()
            personalOutput = result
            respond(result)
        }
    }

    func createDayOneEntry(_ text: String) {
        Task {
            let result = await personalIntegrations.createDayOneEntry(text)
            personalOutput = result
            respond(result)
        }
    }

    private func handleVoiceCommand(_ command: String) {
        let normalized = command.lowercased()

        if normalized.contains("help") {
            respond("You can say show personal, show coder, what is on my calendar, what reminders are open, write journal followed by your entry, open book writer, open AI scout, or go home.")
        } else if normalized.contains("coder") || normalized.contains("coding") || normalized.contains("effort") {
            reloadEfforts()
            openModal(.coder)
            respond("Opening Coder.")
        } else if normalized.contains("calendar") || normalized.contains("schedule") {
            openModal(.personal)
            if normalized.contains("permission") || normalized.contains("access") {
                requestCalendarAccess()
            } else {
                showTodayCalendar()
            }
        } else if normalized.contains("reminder") {
            openModal(.personal)
            if normalized.contains("permission") || normalized.contains("access") {
                requestReminderAccess()
            } else {
                showReminders()
            }
        } else if normalized.contains("write journal") {
            openModal(.personal)
            let text = command.replacingOccurrences(of: "write journal", with: "", options: [.caseInsensitive])
            createDayOneEntry(text)
        } else if normalized.contains("personal") || normalized.contains("day one") || normalized.contains("journal") {
            openModal(.personal)
            respond("Opening Personal.")
        } else if normalized.contains("book") {
            openModal(.bookWriter)
            respond("Opening Book Writer.")
        } else if normalized.contains("post") {
            openModal(.postWriter)
            respond("Opening Post Writer.")
        } else if normalized.contains("scout") || normalized.contains("model") {
            openModal(.aiScout)
            respond("Opening AI Scout.")
        } else if normalized.contains("golf") {
            openModal(.golfer)
            respond("Opening Golfer.")
        } else if normalized.contains("growth") || normalized.contains("company") {
            openModal(.companyGrowth)
            respond("Opening Company Growth.")
        } else if normalized.contains("home") || normalized.contains("voice") {
            selectedSection = .voice
            respond("Back to voice.")
        } else {
            respond("I did not recognize that command yet. Try show personal, show coder, calendar, reminders, or write journal.")
        }
    }

    private func respond(_ text: String) {
        voiceLines.append("App: \(text)")
        speak(text)
    }

    private func speak(_ text: String) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }
}
