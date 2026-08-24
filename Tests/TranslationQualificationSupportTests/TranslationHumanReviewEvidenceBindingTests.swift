import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HumanReviewEvidenceBindingTests {
    @Test func validSignaturesForWrongPacketOrRegistryStillFailTrustedBinding() throws {
        let values = try releaseValues()
        let variants = try [
            SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                reviewPacketSHA256: zeros
            ),
            SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                reviewerRegistrySHA256: zeros
            ),
        ]

        for settlement in variants {
            let result = try evaluateHumanReview(values, settlement)
            #expect(result.reviewBindingFailureCount > 0)
            #expect(!result.passesReleaseReadyGates)
        }
    }

    @Test func changingBoundHashesWithoutResigningFailsClosed() throws {
        let values = try releaseValues()
        let valid = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        let variants = [
            copy(valid, reviewPacketSHA256: zeros),
            copy(valid, reviewerRegistrySHA256: zeros),
        ]

        for settlement in variants {
            let result = try evaluateHumanReview(values, settlement)
            #expect(result.reviewBindingFailureCount > 0)
            #expect(!result.passesReleaseReadyGates)
        }
    }

    @Test func legacySettlementAndUnknownBindingFieldsAreRejected() throws {
        let values = try releaseValues()
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        let data = try SyntheticHumanReviewSettlementFactory.data(settlement)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var legacy = object
        legacy["schemaVersion"] = 1
        legacy.removeValue(forKey: "reviewPacketSHA256")
        legacy.removeValue(forKey: "reviewerRegistrySHA256")
        var unknown = object
        unknown["packetDigest"] = settlement.reviewPacketSHA256

        for candidate in [legacy, unknown] {
            let encoded = try JSONSerialization.data(
                withJSONObject: candidate,
                options: .sortedKeys
            )
            #expect(throws: TranslationQualificationError.self) {
                _ = try TranslationHumanReviewEvidence.decodeSettlement(from: encoded)
            }
        }
    }
}
