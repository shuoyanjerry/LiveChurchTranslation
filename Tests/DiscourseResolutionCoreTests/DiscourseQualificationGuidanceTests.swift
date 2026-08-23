import DiscourseResolutionAPI
import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct DiscourseQualificationGuidanceTests {
    @Test func mapsUnicodeScalarOffsetsToResolverUTF16Ranges() throws {
        let segment = try syntheticSegment()
        let guidance = verifiedMaleGuidance(location: 2)

        let evaluation = try DiscourseQualificationGuidanceEvaluator.evaluate(
            segment: segment,
            guidance: [guidance]
        )

        #expect(evaluation.occurrences.first?.actualGuidanceClass == "verifiedMale")
        #expect(evaluation.occurrences.first?.policyStatusClass == .pass)
        #expect(evaluation.unmappedGuidanceCount == 0)
    }

    @Test func duplicateGuidanceFailsMappingWithoutChoosingOne() throws {
        let segment = try syntheticSegment()
        let guidance = verifiedMaleGuidance(location: 2)

        let evaluation = try DiscourseQualificationGuidanceEvaluator.evaluate(
            segment: segment,
            guidance: [guidance, guidance]
        )

        #expect(evaluation.occurrences.first?.actualGuidanceClass == "duplicateGuidance")
        #expect(evaluation.occurrences.first?.outcomeClass == .mappingFailure)
        #expect(evaluation.duplicateGuidanceLocationCount == 1)
    }

    private func syntheticSegment() throws -> TranslationQualificationSegment {
        try JSONDecoder().decode(
            TranslationQualificationSegment.self,
            from: Data(syntheticSegmentJSON.utf8)
        )
    }

    private func verifiedMaleGuidance(location: Int) -> DiscoursePronounGuidance {
        DiscoursePronounGuidance(
            range: DiscourseTextRange(location: location, length: 1),
            resolution: .verified(
                gender: .male,
                reason: .uniqueCurrentTurnAnchor,
                confidence: 1,
                evidence: DiscourseCorrectionEvidence(sequence: 1, text: "synthetic")
            )
        )
    }
}

private let syntheticSegmentJSON = #"""
    {
      "id": "segment-1",
      "sourceID": "source-1",
      "sequence": 1,
      "unitKind": "content",
      "referenceProfileID": "profile-1",
      "discourseContextIDs": [],
      "locator": {"chinesePages": [1], "englishPages": [1]},
      "originalChinese": "😀他来了。",
      "observedASRAmbiguousChinese": "😀他来了。",
      "referenceEnglish": "Synthetic reference.",
      "featureTags": ["taAmbiguity"],
      "theologyTerms": [],
      "pronounOccurrences": [{
        "id": "occurrence-1",
        "unicodeScalarOffset": 1,
        "originalGlyph": "他",
        "observedGlyph": "他",
        "tokenClass": "singularPronoun",
        "antecedentLabel": "synthetic",
        "evidenceScope": "sameTurn",
        "expectedGuidance": "verifiedMale",
        "expectedEnglishStrategy": "masculine",
        "mustAbstainWhenEvidenceMissing": true,
        "rationaleCode": "synthetic"
      }],
      "referenceWarnings": [],
      "qualification": {
        "semanticScoringEligible": true,
        "exactStringScoringEligible": false,
        "asrCEREligible": false,
        "requiresHumanSemanticReview": false
      }
    }
    """#
