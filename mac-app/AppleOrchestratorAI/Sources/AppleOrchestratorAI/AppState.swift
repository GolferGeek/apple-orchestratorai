import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class AppState {
    var repoRoot: URL?
    var selectedSection: AppSection = .voice
    var activeModal: ModalSurface?
    var recentModalSurfaces: [ModalSurface] = []
    var surface: CoderEffortsSurface?
    var statusMessage = "Ready"
    var hermesOutput = ""
    var piOutput = ""
    var personalOutput = "Calendar, Reminders, and Day One are ready to connect."
    var voiceCommand = ""
    var voicePrompt = "Tell me what you want to do. Try: show coder efforts, check Hermes, check Pi, reload efforts, or help."
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

    func checkHermes() {
        runProbe(script: "scripts/probe-hermes-api.sh", target: .hermes)
    }

    func checkPi() {
        runProbe(script: "scripts/probe-pi.sh", target: .pi)
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

    private func handleVoiceCommand(_ command: String) {
        let normalized = command.lowercased()

        if normalized.contains("help") {
            respond("You can say show coder efforts, show personal, what is on my calendar, what reminders are open, write journal, check Hermes, check Pi, reload efforts, open writing, open AI scout, or go home.")
        } else if normalized.contains("personal") || normalized.contains("calendar") || normalized.contains("reminder") || normalized.contains("journal") || normalized.contains("day one") {
            handlePersonalCommand(command, normalized: normalized)
        } else if normalized.contains("coder") || normalized.contains("effort") || normalized.contains("inbox") {
            reloadEfforts()
            openModal(.coderEfforts)
            respond("Showing Coder Efforts.")
        } else if normalized.contains("check hermes") || normalized.contains("probe hermes") {
            selectedSection = .hermes
            checkHermes()
            respond("Checking Hermes.")
        } else if normalized.contains("hermes") {
            selectedSection = .hermes
            respond("Opening Hermes.")
        } else if normalized.contains("check pi") || normalized.contains("probe pi") {
            selectedSection = .pi
            checkPi()
            respond("Checking Pi.")
        } else if normalized == "pi" || normalized.contains("open pi") || normalized.contains("show pi") {
            selectedSection = .pi
            respond("Opening Pi.")
        } else if normalized.contains("reload") || normalized.contains("refresh") {
            reloadEfforts()
            respond("Reloaded coder efforts.")
        } else if normalized.contains("writing") || normalized.contains("book") || normalized.contains("post") {
            respond("The writing profile surface is not built yet. I can add it after the profile schema is defined.")
        } else if normalized.contains("scout") || normalized.contains("model") {
            respond("The AI Scout surface is not built yet. I can add it after the profile schema is defined.")
        } else if normalized.contains("home") || normalized.contains("voice") {
            selectedSection = .voice
            respond("Back to voice.")
        } else {
            respond("I did not recognize that command yet. Try show coder efforts, check Hermes, or check Pi.")
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

    private func handlePersonalCommand(_ command: String, normalized: String) {
        openModal(.personal)

        if normalized.contains("calendar") || normalized.contains("schedule") {
            if normalized.contains("permission") || normalized.contains("access") {
                requestCalendarAccess()
            } else {
                showTodayCalendar()
            }
        } else if normalized.contains("reminder") {
            if normalized.contains("permission") || normalized.contains("access") {
                requestReminderAccess()
            } else {
                showReminders()
            }
        } else if normalized.contains("write journal") {
            let text = command.replacingOccurrences(of: "write journal", with: "", options: [.caseInsensitive])
            createDayOneEntry(text)
        } else if normalized.contains("day one") {
            respond("Opening Personal. Day One journal entries can be created through the Day One CLI when installed.")
        } else {
            respond("Opening Personal.")
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

    private enum ProbeTarget {
        case hermes
        case pi
    }

    private func runProbe(script: String, target: ProbeTarget) {
        guard let repoRoot else {
            setProbeOutput("Could not locate repository root.", target: target)
            return
        }

        Task {
            let output = await Task.detached(priority: .userInitiated) {
                do {
                    let result = try Shell.run("/bin/bash", [script], cwd: repoRoot)
                    return result.output.isEmpty ? "Exit code: \(result.exitCode)" : result.output
                } catch {
                    return error.localizedDescription
                }
            }.value

            setProbeOutput(output, target: target)
        }
    }

    private func setProbeOutput(_ output: String, target: ProbeTarget) {
        switch target {
        case .hermes:
            hermesOutput = output
        case .pi:
            piOutput = output
        }
    }
}
