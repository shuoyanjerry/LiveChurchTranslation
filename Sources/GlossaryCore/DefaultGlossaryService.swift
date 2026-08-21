import Foundation
import GlossaryAPI

public actor DefaultGlossaryService: GlossaryService {
    private let repository: any GlossaryRepository
    private var entries = DefaultGlossary.entries
    private var revision = 0
    private var hasLoaded = false

    public init(repository: any GlossaryRepository) {
        self.repository = repository
    }

    public func snapshot() async throws -> GlossarySnapshot {
        try await loadIfNeeded()
        return GlossarySnapshot(revision: revision, entries: sortedEntries())
    }

    public func replace(with entries: [GlossaryEntry]) async throws {
        let validated = try validate(entries)
        try await repository.save(validated)
        self.entries = validated
        revision += 1
        hasLoaded = true
    }

    public func upsert(_ entry: GlossaryEntry) async throws {
        try await loadIfNeeded()
        var updated = entries.filter { $0.id != entry.id }
        updated.append(entry)
        try await replace(with: updated)
    }

    public func remove(id: UUID) async throws {
        try await loadIfNeeded()
        try await replace(with: entries.filter { $0.id != id })
    }

    public func restoreDefaults() async throws {
        try await replace(with: DefaultGlossary.entries)
    }

    private func loadIfNeeded() async throws {
        guard !hasLoaded else { return }
        let stored = try await repository.load()
        hasLoaded = true
        guard !stored.isEmpty else { return }
        entries = stored
    }

    private func validate(_ entries: [GlossaryEntry]) throws -> [GlossaryEntry] {
        var seen = Set<String>()
        var seenAliases = Set<String>()
        return try entries.map { entry in
            let source = entry.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = entry.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty else { throw GlossaryError.emptySource }
            guard !target.isEmpty else { throw GlossaryError.emptyTarget }
            guard seen.insert(source.lowercased()).inserted else {
                throw GlossaryError.duplicateSource(source)
            }
            let aliases = try entry.recognitionAliases.map { alias in
                let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw GlossaryError.emptyRecognitionAlias(source)
                }
                guard seenAliases.insert(trimmed.lowercased()).inserted else {
                    throw GlossaryError.duplicateRecognitionAlias(trimmed)
                }
                return trimmed
            }
            return GlossaryEntry(
                id: entry.id,
                source: source,
                target: target,
                recognitionAliases: aliases,
                isEnabled: entry.isEnabled
            )
        }
    }

    private func sortedEntries() -> [GlossaryEntry] {
        entries.sorted {
            if $0.source.count == $1.source.count { return $0.source < $1.source }
            return $0.source.count > $1.source.count
        }
    }
}
