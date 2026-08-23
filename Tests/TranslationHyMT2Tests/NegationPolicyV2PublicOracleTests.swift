import Testing

@Suite("Negation Policy V2 independent public oracle")
struct NegationPolicyV2PublicOracleTests {
    @Test(arguments: NegationPolicyV2PublicOracle.cases)
    func matchesHumanAuthoredOracle(oracle: NegationPolicyV2OracleCase) throws {
        let fixture = try #require(
            PublicNegationChallengeFixtures.all.first { $0.id == oracle.challengeID }
        )

        #expect(
            NegationPolicyV2.disposition(
                source: fixture.source,
                target: fixture.target
            ) == oracle.expected
        )
    }

    @Test("oracle covers each of the 18 challenge fixtures exactly once")
    func oracleCoverageIsExact() {
        let fixtureIDs = Set(PublicNegationChallengeFixtures.all.map(\.id))
        let oracleIDs = NegationPolicyV2PublicOracle.cases.map(\.challengeID)

        #expect(PublicNegationChallengeFixtures.all.count == 18)
        #expect(oracleIDs.count == 18)
        #expect(Set(oracleIDs).count == oracleIDs.count)
        #expect(Set(oracleIDs) == fixtureIDs)
    }

    @Test("single overt cue in the wrong clause remains review-only")
    func wrongScopeCannotBecomeStructuralPass() throws {
        let fixture = try #require(
            PublicNegationChallengeFixtures.all.first {
                $0.id == "single-bare-negation-scope-shift"
            }
        )

        #expect(
            NegationPolicyV2.disposition(
                source: fixture.source,
                target: fixture.target
            )
                == .humanReviewRequired(
                    reason: .mixedPolarityClauses(functionalCount: 1)
                )
        )
    }
}
