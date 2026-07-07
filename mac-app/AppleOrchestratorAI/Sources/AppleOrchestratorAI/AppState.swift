import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var repoRoot: URL?
    var surface: CoderEffortsSurface?
    var statusMessage = "Ready"
    var hermesOutput = ""
    var piOutput = ""

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
