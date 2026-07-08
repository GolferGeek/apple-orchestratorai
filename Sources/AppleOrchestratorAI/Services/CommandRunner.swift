import Foundation

struct CommandResult: Equatable {
    let exitCode: Int32
    let output: String
    let errorOutput: String
}

struct CommandRunner {
    func run(_ executable: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(exitCode: 127, output: "", errorOutput: error.localizedDescription)
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(exitCode: process.terminationStatus, output: output, errorOutput: errorOutput)
    }

    func findCommand(_ command: String) -> String? {
        let result = run("/usr/bin/env", ["which", command])
        guard result.exitCode == 0 else {
            return nil
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
