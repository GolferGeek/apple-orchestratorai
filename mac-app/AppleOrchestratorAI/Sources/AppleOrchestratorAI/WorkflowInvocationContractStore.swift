import Foundation

struct WorkflowInvocationContractStore {
    private let sectionHeading = "## Invocation Contracts"

    func load(url: URL?) -> [String: String] {
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }

        let pattern = #"<!-- ao-invocation-contract id=\"([^\"]+)\" -->\n([\s\S]*?)<!-- /ao-invocation-contract -->"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let range = NSRange(text.startIndex..., in: text)
        var contracts: [String: String] = [:]

        expression.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match,
                  let idRange = Range(match.range(at: 1), in: text),
                  let bodyRange = Range(match.range(at: 2), in: text) else {
                return
            }
            contracts[String(text[idRange])] = String(text[bodyRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return contracts
    }

    func save(_ contracts: [String: String], url: URL?) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        var text = try String(contentsOf: url, encoding: .utf8)
        if let start = text.range(of: "\n\(sectionHeading)\n"),
           let end = text.range(of: "<!-- /ao-invocation-contracts -->", range: start.lowerBound..<text.endIndex) {
            text.removeSubrange(start.lowerBound..<end.upperBound)
        }

        let entries = contracts
            .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.key < $1.key }
            .map { id, body in
                [
                    "<!-- ao-invocation-contract id=\"\(id)\" -->",
                    body.trimmingCharacters(in: .whitespacesAndNewlines),
                    "<!-- /ao-invocation-contract -->"
                ].joined(separator: "\n")
            }

        guard !entries.isEmpty else {
            try text.trimmingCharacters(in: .whitespacesAndNewlines).appending("\n").write(to: url, atomically: true, encoding: .utf8)
            return
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            + "\n\n\(sectionHeading)\n\n"
            + entries.joined(separator: "\n\n")
            + "\n\n<!-- /ao-invocation-contracts -->"
            + "\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
