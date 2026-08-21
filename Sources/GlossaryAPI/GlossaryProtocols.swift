import Foundation

public protocol GlossaryRepository: Sendable {
    func load() async throws -> [GlossaryEntry]
    func save(_ entries: [GlossaryEntry]) async throws
}

public protocol GlossaryService: Sendable {
    func snapshot() async throws -> GlossarySnapshot
    func replace(with entries: [GlossaryEntry]) async throws
    func upsert(_ entry: GlossaryEntry) async throws
    func remove(id: UUID) async throws
    func restoreDefaults() async throws
}
