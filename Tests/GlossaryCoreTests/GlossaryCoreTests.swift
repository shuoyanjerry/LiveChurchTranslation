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
        #expect(entries[0].sourceAliases.isEmpty)
        #expect(entries[0].targetVariants.isEmpty)
        #expect(entries[0].enforcement == .preferred)
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

    @Test func servicePreservesSemanticAliasesVariantsAndEnforcement() async throws {
        let repository = InMemoryGlossaryRepository()
        let service = DefaultGlossaryService(repository: repository)
        try await service.replace(with: [
            GlossaryEntry(
                source: "洗礼",
                target: "baptism",
                sourceAliases: [" 受浸 "],
                targetVariants: [" baptized "],
                enforcement: .required,
                note: "  sacrament term  "
            )
        ])

        let entry = try #require(try await service.snapshot().entries.first)
        #expect(entry.sourceAliases == ["受浸"])
        #expect(entry.targetVariants == ["baptized"])
        #expect(entry.enforcement == .required)
        #expect(entry.note == "sacrament term")
    }

    @Test func recognitionAliasCannotShadowARealSourceAlias() async throws {
        let service = DefaultGlossaryService(repository: InMemoryGlossaryRepository())

        await #expect(throws: GlossaryError.self) {
            try await service.replace(with: [
                GlossaryEntry(source: "洗礼", target: "baptism", sourceAliases: ["受浸"]),
                GlossaryEntry(
                    source: "浸礼",
                    target: "immersion",
                    recognitionAliases: ["受浸"]
                ),
            ])
        }
    }
}

private actor InMemoryGlossaryRepository: GlossaryRepository {
    private var entries: [GlossaryEntry] = []

    func load() async throws -> [GlossaryEntry] { entries }
    func save(_ entries: [GlossaryEntry]) async throws { self.entries = entries }
}
