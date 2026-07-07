import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechCommandRecognizer {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var isListening: Bool {
        audioEngine.isRunning
    }

    func start(
        onResult: @escaping @MainActor (String, Bool) -> Void,
        onStatus: @escaping @MainActor (String) -> Void
    ) async {
        guard await requestPermissions(onStatus: onStatus) else {
            return
        }

        stop()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            onStatus("Listening...")
        } catch {
            onStatus("Could not start microphone: \(error.localizedDescription)")
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                if let result {
                    onResult(result.bestTranscription.formattedString, result.isFinal)
                }

                if let error {
                    onStatus("Speech recognition stopped: \(error.localizedDescription)")
                    self.stop()
                }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func requestPermissions(onStatus: @escaping @MainActor (String) -> Void) async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAllowed else {
            onStatus("Speech recognition permission was not granted.")
            return false
        }

        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                continuation.resume(returning: allowed)
            }
        }

        guard microphoneAllowed else {
            onStatus("Microphone permission was not granted.")
            return false
        }

        return true
    }
}
