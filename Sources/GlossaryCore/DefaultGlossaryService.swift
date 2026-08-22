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
}

extension DefaultGlossaryService {
    private func validate(_ entries: [GlossaryEntry]) throws -> [GlossaryEntry] {
        var validation = GlossaryValidationState()
        let validated = try entries.map {
            try sanitizedEntry($0, validation: &validation)
        }
        try validation.validateCrossCategoryConflicts()
        return validated
    }

    private func sanitizedEntry(
        _ entry: GlossaryEntry,
        validation: inout GlossaryValidationState
    ) throws -> GlossaryEntry {
        let source = try nonEmpty(entry.source, error: GlossaryError.emptySource)
        let target = try nonEmpty(entry.target, error: GlossaryError.emptyTarget)
        try validation.registerSource(source)
        let sourceAliases = try sanitizedSourceAliases(
            entry.sourceAliases,
            source: source,
            validation: &validation
        )
        let recognitionAliases = try sanitizedRecognitionAliases(
            entry.recognitionAliases,
            source: source,
            validation: &validation
        )
        let targetVariants = try sanitizedTargetVariants(entry.targetVariants, source: source)
        return GlossaryEntry(
            id: entry.id,
            source: source,
            target: target,
            sourceAliases: sourceAliases,
            recognitionAliases: recognitionAliases,
            targetVariants: targetVariants,
            enforcement: entry.enforcement,
            note: entry.note.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: entry.isEnabled
        )
    }

    private func sanitizedSourceAliases(
        _ aliases: [String],
        source: String,
        validation: inout GlossaryValidationState
    ) throws -> [String] {
        try aliases.map {
            let alias = try nonEmpty($0, error: GlossaryError.emptySourceAlias(source))
            try validation.registerSourceAlias(alias)
            return alias
        }
    }

    private func sanitizedRecognitionAliases(
        _ aliases: [String],
        source: String,
        validation: inout GlossaryValidationState
    ) throws -> [String] {
        try aliases.map {
            let alias = try nonEmpty($0, error: GlossaryError.emptyRecognitionAlias(source))
            try validation.registerRecognitionAlias(alias)
            return alias
        }
    }

    private func sanitizedTargetVariants(
        _ variants: [String],
        source: String
    ) throws -> [String] {
        try variants.map {
            try nonEmpty($0, error: GlossaryError.emptyTargetVariant(source))
        }
    }

    private func nonEmpty(_ value: String, error: GlossaryError) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw error }
        return trimmed
    }

    private func sortedEntries() -> [GlossaryEntry] {
        entries.sorted {
            if $0.source.count == $1.source.count { return $0.source < $1.source }
            return $0.source.count > $1.source.count
        }
    }
}

private struct GlossaryValidationState {
    private var sources = Set<String>()
    private var sourceAliases = Set<String>()
    private var recognitionAliases = Set<String>()

    mutating func registerSource(_ source: String) throws {
        guard sources.insert(key(for: source)).inserted else {
            throw GlossaryError.duplicateSource(source)
        }
    }

    mutating func registerSourceAlias(_ alias: String) throws {
        guard sourceAliases.insert(key(for: alias)).inserted else {
            throw GlossaryError.duplicateSourceAlias(alias)
        }
    }

    mutating func registerRecognitionAlias(_ alias: String) throws {
        guard recognitionAliases.insert(key(for: alias)).inserted else {
            throw GlossaryError.duplicateRecognitionAlias(alias)
        }
    }

    func validateCrossCategoryConflicts() throws {
        if let duplicate = sources.intersection(sourceAliases).first {
            throw GlossaryError.duplicateSourceAlias(duplicate)
        }
        let semanticTerms = sources.union(sourceAliases)
        if let conflict = recognitionAliases.first(where: semanticTerms.contains) {
            throw GlossaryError.conflictingAlias(conflict)
        }
    }

    private func key(for value: String) -> String {
        value.lowercased()
    }
}
