import Foundation

extension TranslationHumanReviewPacket {
    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(
            decoder,
            [
                "schemaVersion", "policyRevision", "reportFileSHA256",
                "postflightFileSHA256", "reportBinding", "items",
            ]
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        policyRevision = try values.decode(String.self, forKey: .policyRevision)
        reportFileSHA256 = try values.decode(String.self, forKey: .reportFileSHA256)
        postflightFileSHA256 = try values.decode(String.self, forKey: .postflightFileSHA256)
        reportBinding = try values.decode(
            TranslationHumanReviewReportBinding.self,
            forKey: .reportBinding
        )
        items = try values.decode([TranslationHumanReviewPacketItem].self, forKey: .items)
    }
}

extension TranslationHumanReviewPacketItem {
    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(
            decoder,
            [
                "itemID", "sourceText", "targetText", "referenceText", "reviewKind",
                "reviewSubject", "humanResolvable",
            ]
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try values.decode(String.self, forKey: .itemID)
        sourceText = try values.decode(String.self, forKey: .sourceText)
        targetText = try values.decode(String.self, forKey: .targetText)
        referenceText = try values.decode(String.self, forKey: .referenceText)
        reviewKind = try values.decode(String.self, forKey: .reviewKind)
        reviewSubject = try values.decode(String.self, forKey: .reviewSubject)
        humanResolvable = try values.decode(Bool.self, forKey: .humanResolvable)
    }
}

extension TranslationHumanReviewEvidence {
    public static func decodeReviewPacket(
        from data: Data
    ) throws -> TranslationHumanReviewPacket {
        try TranslationJSONDuplicateKeyValidator.validate(data)
        let packet: TranslationHumanReviewPacket
        do {
            packet = try JSONDecoder().decode(TranslationHumanReviewPacket.self, from: data)
        } catch let error as TranslationQualificationError {
            throw error
        } catch {
            throw TranslationQualificationError.invalidJSON(
                "human review packet does not match its strict schema"
            )
        }
        try HumanReviewPacketValidator.validate(packet)
        guard data == (try encodeReviewPacket(packet)) else {
            throw TranslationQualificationError.invalidReport(
                "human review packet is not canonical"
            )
        }
        return packet
    }
}
