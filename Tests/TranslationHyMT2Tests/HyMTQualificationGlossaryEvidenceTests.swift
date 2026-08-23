import Foundation
import Testing
import TranslationQualificationSupport
@testable import TranslationHyMT2

@Suite struct HyMTQualificationGlossaryEvidenceTests {
    @Test func promptGlossaryRemainsTheProductionDefaultCatalog() {
        let source = "请传讲救赎与基督。"
        let matched = HyMTQualificationGlossary.matchedTerms(in: source)

        #expect(matched.isEmpty)
    }

    @Test func retainsExactCatalogEvidenceWhenLongerPromptTermWins() throws {
        let source = "三位一体的神赐下恩典。"
        let matched = HyMTQualificationGlossary.matchedTerms(in: source)
        let prompted = HyMTQualificationGlossary.promptExpectations(
            source: source,
            matchedTerms: matched,
            limit: 64
        )
        let evidence = try HyMTQualificationGlossary.evidenceExpectations(
            source: source,
            matchedTerms: matched,
            manifestTerms: ["三位一体"],
            limit: 64
        )

        #expect(!prompted.map(\.source).contains("三位一体"))
        #expect(evidence.map(\.source).contains("三位一体"))
        #expect(evidence.count == prompted.count + 1)
    }

    @Test func rejectsInexactKnownAndUnknownManifestLabels() {
        let fixtures = [
            (source: "他准备受浸。", terms: ["受浸"]),
            (source: "这是恩典。", terms: ["恩"]),
            (source: "这是福\u{FE00}音。", terms: ["福音"]),
            (source: "这是合成神学词。", terms: ["合成神学词"]),
            (source: "这是恩典。", terms: ["恩典", "恩典"]),
        ]

        for fixture in fixtures {
            #expect(throws: TranslationQualificationError.self) {
                _ = try HyMTQualificationGlossary.evidenceExpectations(
                    source: fixture.source,
                    matchedTerms: HyMTQualificationGlossary.matchedTerms(in: fixture.source),
                    manifestTerms: fixture.terms,
                    limit: 64
                )
            }
        }
    }

    @Test func catalogHashIsDeterministicSHA256() {
        let hash = HyMTQualificationGlossary.catalogSHA256

        #expect(
            HyMTQualificationGlossary.theologyPolicyID
                == "hymt-qualification-theology-surface-v1")
        #expect(hash == HyMTQualificationGlossary.catalogSHA256)
        #expect(hash == "c10e3635558ab81dec8221898578f11a7966d95d891ad872df24e5dd2300bf59")
    }

    @Test func genericSinRequiresACompleteExplicitEnglishToken() throws {
        let segment = try syntheticGlossarySegment(
            source: "合成术语覆盖：罪。",
            theologyTerms: ["罪"]
        )
        let expectation = try HyMTQualificationTheologyCatalog.expectation(forExactLabel: "罪")
        let falsePositive = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "A sincere synthetic sentence since yesterday.",
            terms: [expectation]
        )
        let exactMatch = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "A synthetic sentence about sin.",
            terms: [expectation]
        )

        #expect(falsePositive.terms.first?.status == .fail)
        #expect(exactMatch.terms.first?.status == .pass)
    }

    @MainActor
    @Test func runnerRejectsMissingCatalogBeforeAnyCompletion() async throws {
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success("Unused synthetic response")],
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )
        let segment = try syntheticGlossarySegment(
            source: "这是合成神学词。",
            theologyTerms: ["合成神学词"]
        )

        await #expect(throws: TranslationQualificationError.self) {
            _ = try await HyMTQualificationRunner(
                provider: harness.provider,
                recorder: recorder,
                pronounTraceRecorder: traceRecorder
            ).run(segments: [segment])
        }
        #expect(await harness.transport.completionRequests().isEmpty)
        await harness.provider.shutdown()
    }
}

private func syntheticGlossarySegment(
    source: String,
    theologyTerms: [String]
) throws -> TranslationQualificationSegment {
    let value: [String: Any] = [
        "id": "synthetic-glossary", "sourceID": "synthetic-source", "sequence": 1,
        "unitKind": "content", "referenceProfileID": "synthetic-profile",
        "discourseContextIDs": [],
        "locator": ["chinesePages": [1], "englishPages": [1]],
        "originalChinese": source, "observedASRAmbiguousChinese": source,
        "referenceEnglish": "Synthetic reference.", "featureTags": ["theologyTerm"],
        "theologyTerms": theologyTerms, "pronounOccurrences": [], "referenceWarnings": [],
        "qualification": [
            "semanticScoringEligible": true, "exactStringScoringEligible": false,
            "asrCEREligible": false, "requiresHumanSemanticReview": true,
        ],
    ]
    let data = try JSONSerialization.data(withJSONObject: value)
    return try JSONDecoder().decode(TranslationQualificationSegment.self, from: data)
}
