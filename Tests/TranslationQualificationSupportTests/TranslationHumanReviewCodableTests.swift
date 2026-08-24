import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationHumanReviewCodableTests {
    @Test func officialDecoderRoundTripsStrictSettlement() throws {
        let values = try releaseValues()
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        let data = try TranslationHumanReviewEvidence.encodeSettlement(settlement)

        #expect(try TranslationHumanReviewEvidence.decodeSettlement(from: data) == settlement)
    }

    @Test func serializedBlindSidecarContainsOnlyOpaqueReviewItemIDs() throws {
        let values = try releaseValues()
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        let json = try #require(String(data: JSONEncoder().encode(settlement), encoding: .utf8))

        for sensitive in ["source-a", "source-b", "他在这里", "segmentID", "sourceID"] {
            #expect(!json.contains(sensitive))
        }
        #expect(json.contains("itemID"))
        for submission in settlement.submissions {
            #expect(submission.reviewer.reviewerID.count == 73)
            #expect(
                submission.reviewer.reviewerID
                    == (try TranslationHumanReviewEvidence.reviewerID(
                        forPublicKeyBase64: submission.reviewer.publicKeyBase64
                    ))
            )
        }
    }

    @Test func rejectsMissingUnknownAndUnknownEnumFields() throws {
        let values = try releaseValues()
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        let variants = try [
            mutate(settlement) { $0.removeValue(forKey: "policyRevision") },
            mutate(settlement) { $0["unexpected"] = true },
            mutate(settlement) { object in
                var submissions = try #require(object["submissions"] as? [[String: Any]])
                submissions[0]["unexpected"] = true
                object["submissions"] = submissions
            },
            mutate(settlement) { object in
                var submissions = try #require(object["submissions"] as? [[String: Any]])
                var reviewer = try #require(submissions[0]["reviewer"] as? [String: Any])
                reviewer["reviewerRole"] = "unknown"
                submissions[0]["reviewer"] = reviewer
                object["submissions"] = submissions
            },
            mutate(settlement) { object in
                var submissions = try #require(object["submissions"] as? [[String: Any]])
                var reviews = try #require(submissions[0]["reviews"] as? [[String: Any]])
                reviews[0]["verdict"] = "unknown"
                submissions[0]["reviews"] = reviews
                object["submissions"] = submissions
            },
        ]

        for data in variants {
            #expect(throws: TranslationQualificationError.self) {
                try TranslationHumanReviewEvidence.decodeSettlement(from: data)
            }
        }
    }

    @Test func rejectsDuplicateJSONFieldsBeforeFoundationCollapsesThem() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        let json = try #require(String(data: JSONEncoder().encode(settlement), encoding: .utf8))
        let duplicated = json.replacingOccurrences(
            of: "\"schemaVersion\":2",
            with: "\"schemaVersion\":2,\"schemaVersion\":2"
        )

        #expect(duplicated != json)
        #expect(throws: TranslationQualificationError.self) {
            try TranslationHumanReviewEvidence.decodeSettlement(
                from: Data(duplicated.utf8)
            )
        }
        let result = TranslationQualificationReleaseGate.evaluate(
            values.report,
            expectation: values.expectation,
            humanReviewSidecar: Data(duplicated.utf8)
        )
        #expect(result.reviewBindingFailureCount > 0)
        #expect(!result.passesReleaseReadyGates)
    }
}

private func mutate(
    _ settlement: TranslationHumanReviewSettlement,
    _ mutation: (inout [String: Any]) throws -> Void
) throws -> Data {
    var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(settlement)) as? [String: Any]
    )
    try mutation(&object)
    return try JSONSerialization.data(withJSONObject: object)
}
