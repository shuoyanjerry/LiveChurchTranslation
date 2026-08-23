import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounAnchorBoundaryTests {
    @Test func rejectsUnsafeCharactersImmediatelyAfterAnchor() throws {
        let fixture = try femaleFixture()
        let anchor = fixture.plan.occurrences[0].protectedBlock
        let unsafeSuffixes = [
            "nonsense", "\u{0430}", "1", "\u{0301}", "_value",
            "'s", "’s", "/her", "-like", "—like", "\u{00A0}", "\u{200B}",
        ]

        for suffix in unsafeSuffixes {
            assertRejected("She\(anchor)\(suffix)", fixture: fixture)
        }
    }

    @Test func rejectsConnectorsAtPronounLeftBoundary() throws {
        let fixture = try femaleFixture()
        let anchor = fixture.plan.occurrences[0].protectedBlock
        let unsafePrefixes = [
            "x", "1", "_", "'", "’", "/", "-", "—", "<", "#", "@", "&", "`",
        ]

        for prefix in unsafePrefixes {
            assertRejected("\(prefix)She\(anchor) continued.", fixture: fixture)
        }
    }

    private func assertRejected(_ output: String, fixture: Fixture) {
        #expect(
            !validationIssues(output: output, source: fixture.source, plan: fixture.plan)
                .isEmpty
        )
    }

    private struct Fixture {
        let source: String
        let plan: HyMT2PronounPlan
    }

    private func femaleFixture() throws -> Fixture {
        let source = "她继续。"
        return try Fixture(
            source: source,
            plan: makePronounPlan(
                source: source,
                guidance: [guidance(0, .verifiedFemale)]
            )
        )
    }
}
