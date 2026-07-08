import Foundation

struct RuntimeManifestLoader {
    func load() async -> RuntimeManifest? {
        do {
            let data = try Data(contentsOf: ProjectPaths.runtimeManifest)
            return try JSONDecoder().decode(RuntimeManifest.self, from: data)
        } catch {
            return nil
        }
    }
}
