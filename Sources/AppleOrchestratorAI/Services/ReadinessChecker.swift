import Foundation

struct ReadinessChecker {
    private let commands = CommandRunner()

    func check() async -> ReadinessReport {
        var checks: [ReadinessCheck] = []

        checks.append(systemVersionCheck())
        checks.append(memoryCheck())
        checks.append(commandCheck(id: "xcodebuild", label: "Xcode Build Tool", command: "xcodebuild", required: true))
        checks.append(commandCheck(id: "swift", label: "Swift", command: "swift", required: true))
        checks.append(commandCheck(id: "codesign", label: "Codesign", command: "codesign", required: true))
        checks.append(commandCheck(id: "hdiutil", label: "DMG Tool", command: "hdiutil", required: true))
        checks.append(commandCheck(id: "hermes", label: "Hermes", command: "hermes", required: true, fallbackPath: ProjectPaths.root.appending(path: ".runtime/venvs/hermes-dev/bin/hermes").path))
        checks.append(commandCheck(id: "pi", label: "Pi", command: "pi", required: false))
        checks.append(commandCheck(id: "ollama", label: "Ollama", command: "ollama", required: false))
        checks.append(jsonFileCheck(id: "runtime-manifest", label: "Runtime Manifest", url: ProjectPaths.runtimeManifest))
        checks.append(jsonFileCheck(id: "document-onboarding", label: "Document Onboarding Workflow", url: ProjectPaths.legalWorkflowRoot.appending(path: "document-onboarding.workflow.json")))

        return ReadinessReport(generatedAt: Date(), checks: checks)
    }

    private func systemVersionCheck() -> ReadinessCheck {
        let result = commands.run("/usr/bin/sw_vers", ["-productVersion"])
        let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReadinessCheck(
            id: "macos-version",
            label: "macOS",
            status: version.isEmpty ? .warning : .ok,
            detail: version.isEmpty ? "Could not determine macOS version." : version
        )
    }

    private func memoryCheck() -> ReadinessCheck {
        let result = commands.run("/usr/sbin/sysctl", ["-n", "hw.memsize"])
        let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let bytes = Double(raw) else {
            return ReadinessCheck(id: "memory", label: "Memory", status: .warning, detail: "Could not determine memory.")
        }

        let gb = bytes / 1024 / 1024 / 1024
        let status: ReadinessStatus = gb >= 32 ? .ok : .warning
        return ReadinessCheck(id: "memory", label: "Memory", status: status, detail: String(format: "%.1f GB", gb))
    }

    private func commandCheck(id: String, label: String, command: String, required: Bool, fallbackPath: String? = nil) -> ReadinessCheck {
        if let path = commands.findCommand(command), !path.isEmpty {
            return ReadinessCheck(id: id, label: label, status: .ok, detail: path)
        }

        if let fallbackPath, FileManager.default.isExecutableFile(atPath: fallbackPath) {
            return ReadinessCheck(id: id, label: label, status: .ok, detail: fallbackPath)
        }

        return ReadinessCheck(
            id: id,
            label: label,
            status: required ? .missing : .warning,
            detail: required ? "\(command) is required but was not found on PATH." : "\(command) was not found on PATH."
        )
    }

    private func jsonFileCheck(id: String, label: String, url: URL) -> ReadinessCheck {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ReadinessCheck(id: id, label: label, status: .missing, detail: url.path)
        }

        do {
            _ = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            return ReadinessCheck(id: id, label: label, status: .ok, detail: url.path)
        } catch {
            return ReadinessCheck(id: id, label: label, status: .failed, detail: error.localizedDescription)
        }
    }
}
