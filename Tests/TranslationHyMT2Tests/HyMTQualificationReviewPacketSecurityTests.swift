import Foundation
import Testing
import TranslationQualificationSupport

extension HyMTQualificationReviewEvidenceTests {
    @Test func packetBodyMutationChangesCanonicalDigest() throws {
        let values = try semanticReport()
        let packet = try TranslationHumanReviewEvidence.makeReviewPacket(
            report: values.report,
            expectation: values.expectation,
            reportFileSHA256: sha("7"),
            postflightFileSHA256: sha("8")
        )
        let original = try TranslationHumanReviewEvidence.encodeReviewPacket(packet)
        var object = try #require(
            JSONSerialization.jsonObject(with: original) as? [String: Any]
        )
        var items = try #require(object["items"] as? [[String: Any]])
        items[0]["sourceText"] = "被篡改的评审正文"
        object["items"] = items
        let mutatedJSON = try JSONSerialization.data(
            withJSONObject: object,
            options: .sortedKeys
        )
        let mutatedPacket = try JSONDecoder().decode(
            TranslationHumanReviewPacket.self,
            from: mutatedJSON
        )
        let mutated = try TranslationHumanReviewEvidence.encodeReviewPacket(mutatedPacket)

        #expect(try TranslationHumanReviewEvidence.decodeReviewPacket(from: mutated) == mutatedPacket)
        #expect(
            TranslationQualificationSHA256.hash(data: original)
                != TranslationQualificationSHA256.hash(data: mutated)
        )
    }

    @Test func legacyUnknownDuplicateUnsortedAndNoncanonicalPacketsAreRejected() throws {
        let values = try semanticReport()
        let packet = try TranslationHumanReviewEvidence.makeReviewPacket(
            report: values.report,
            expectation: values.expectation,
            reportFileSHA256: sha("7"),
            postflightFileSHA256: sha("8")
        )
        let data = try TranslationHumanReviewEvidence.encodeReviewPacket(packet)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let invalid = try structuredPacketMutations(object) + textualPacketMutations(data)

        for candidate in invalid {
            #expect(throws: TranslationQualificationError.self) {
                _ = try TranslationHumanReviewEvidence.decodeReviewPacket(from: candidate)
            }
        }
    }
}

private func structuredPacketMutations(
    _ object: [String: Any]
) throws -> [Data] {
    var legacy = object
    legacy["schemaVersion"] = 1
    var unknown = object
    unknown["unexpected"] = true
    var unsorted = object
    unsorted["items"] = Array(
        try #require(object["items"] as? [[String: Any]]).reversed()
    )
    return try [legacy, unknown, unsorted].map {
        try JSONSerialization.data(withJSONObject: $0, options: .sortedKeys)
    }
}

private func textualPacketMutations(_ data: Data) throws -> [Data] {
    let text = try #require(String(data: data, encoding: .utf8))
    let duplicate = Data(
        text.replacingOccurrences(
            of: "{",
            with: "{\"schemaVersion\":2,",
            options: [],
            range: text.startIndex..<text.index(after: text.startIndex)
        ).utf8
    )
    var noncanonical = Data(" \n".utf8)
    noncanonical.append(data)
    return [duplicate, noncanonical]
}
