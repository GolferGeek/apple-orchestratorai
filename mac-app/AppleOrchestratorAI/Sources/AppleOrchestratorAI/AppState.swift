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
    var statusMessage = "Ready"
    var hermesOutput = ""
    var piOutput = ""
    var voiceCommand = ""
    var voicePrompt = "Tell me what workflow you want to build or run. Try: show workflows, check Hermes, check Pi, or help."
    var voiceLines: [String] = [
        "App: Tell me what you want to do."
    ]
    var isListening = false
    var speechStatus = "Microphone idle."

    private let speechSynthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SpeechCommandRecognizer()

    init() {
        repoRoot = RepositoryLocator.findRepoRoot()
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
            respond("You can say show workflows, check Hermes, check Pi, open legal workflows, or go home.")
        } else if normalized.contains("check hermes") || normalized.contains("probe hermes") {
            openModal(.hermes)
            checkHermes()
            respond("Checking Hermes.")
        } else if normalized.contains("hermes") {
            openModal(.hermes)
            respond("Opening Hermes.")
        } else if normalized.contains("check pi") || normalized.contains("probe pi") {
            openModal(.pi)
            checkPi()
            respond("Checking Pi.")
        } else if normalized == "pi" || normalized.contains("open pi") || normalized.contains("show pi") {
            openModal(.pi)
            respond("Opening Pi.")
        } else if normalized.contains("legal") || normalized.contains("workflow") {
            respond("The workflow catalog surface is next. For now, I can open advanced Hermes and Pi panels.")
        } else if normalized.contains("home") || normalized.contains("voice") {
            selectedSection = .voice
            respond("Back to voice.")
        } else {
            respond("I did not recognize that command yet. Try show workflows, check Hermes, or check Pi.")
        }
    }

    func openModal(_ modal: ModalSurface) {
        if !recentModalSurfaces.contains(where: { $0 == modal }) {
            recentModalSurfaces.append(modal)
        }
        activeModal = modal
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
