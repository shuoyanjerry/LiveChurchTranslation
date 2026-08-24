import Testing

@Suite struct HyMTQualificationGlossaryAliasTests {
    @Test func evidenceUsesTheMatchedAliasSurfaceInsteadOfAnAbsentCanonicalLabel() throws {
        let source = "他准备受浸。"
        let matched = HyMTQualificationGlossary.matchedTerms(in: source)
        let expectations = HyMTQualificationGlossary.promptExpectations(
            source: source,
            matchedTerms: matched,
            limit: 64
        )
        let baptism = try #require(
            expectations.first { $0.preferredTarget == "baptism" }
        )

        #expect(baptism.source == "受浸")
        #expect(source.localizedStandardContains(baptism.source))
    }
}
