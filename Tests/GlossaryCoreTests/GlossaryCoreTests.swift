import Foundation
import GlossaryAPI
import GlossaryCore
import Testing

@Suite struct GlossaryCoreTests {
    @Test func defaultsAreAvailableWhenRepositoryIsEmpty() async throws {
        let service = DefaultGlossaryService(repository: InMemoryGlossaryRepository())
        let snapshot = try await service.snapshot()
        #expect(
            snapshot.entries.contains {
                $0.source == "因信称义" && $0.target == "justification by faith"
            })
        #expect(
            snapshot.entries.contains {
                $0.source == "三位一体的神" && $0.target == "the triune God"
            })
        #expect(
            snapshot.entries.contains {
                $0.source == "救恩" && $0.recognitionAliases == ["休恩"]
            })
    }

    @Test func legacyJSONWithoutRecognitionAliasesRemainsDecodable() throws {
        let id = UUID()
        let data = Data(
            """
            [{"id":"\(id.uuidString)","source":"救恩","target":"salvation","isEnabled":true}]
            """.utf8
        )

        let entries = try JSONDecoder().decode([GlossaryEntry].self, from: data)

        #expect(entries.count == 1)
        #expect(entries[0].recognitionAliases.isEmpty)
    }

    @Test func serviceTrimsAndPersistsRecognitionAliases() async throws {
        let repository = InMemoryGlossaryRepository()
        let service = DefaultGlossaryService(repository: repository)

        try await service.replace(with: [
            GlossaryEntry(
                source: "救恩",
                target: "salvation",
                recognitionAliases: [" 休恩 "]
            )
        ])

        #expect(try await service.snapshot().entries[0].recognitionAliases == ["休恩"])
    }
}

private actor InMemoryGlossaryRepository: GlossaryRepository {
    private var entries: [GlossaryEntry] = []

    func load() async throws -> [GlossaryEntry] { entries }
    func save(_ entries: [GlossaryEntry]) async throws { self.entries = entries }
}
