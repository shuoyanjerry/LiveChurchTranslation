import Foundation
import GlossaryAPI

public actor FileGlossaryRepository: GlossaryRepository {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        fileURL = directory.appending(path: "glossary.json")
        self.fileManager = fileManager
    }

    public func load() async throws -> [GlossaryEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder().decode([GlossaryEntry].self, from: data)
        } catch {
            throw GlossaryError.persistenceFailed(error.localizedDescription)
        }
    }

    public func save(_ entries: [GlossaryEntry]) async throws {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder().encode(entries)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            throw GlossaryError.persistenceFailed(error.localizedDescription)
        }
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func decoder() -> JSONDecoder {
        JSONDecoder()
    }
}
