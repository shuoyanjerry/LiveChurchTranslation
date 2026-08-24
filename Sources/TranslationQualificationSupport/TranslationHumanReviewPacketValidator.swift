enum HumanReviewPacketValidator {
    static func validate(_ packet: TranslationHumanReviewPacket) throws {
        let itemIDs = packet.items.map(\.itemID)
        guard
            packet.schemaVersion == TranslationHumanReviewPacket.currentSchemaVersion,
            packet.policyRevision == TranslationHumanReviewEvidence.currentPolicyRevision,
            TranslationProvenanceValidator.isSHA(packet.reportFileSHA256),
            TranslationProvenanceValidator.isSHA(packet.postflightFileSHA256),
            validBinding(packet.reportBinding),
            itemIDs == itemIDs.sorted(),
            Set(itemIDs).count == itemIDs.count,
            packet.items.allSatisfy(validItem)
        else {
            throw TranslationQualificationError.invalidReport(
                "human review packet is invalid"
            )
        }
    }

    private static func validBinding(
        _ binding: TranslationHumanReviewReportBinding
    ) -> Bool {
        TranslationProvenanceValidator.isSHA(binding.reportSHA256)
            && TranslationProvenanceValidator.isSHA(binding.manifestSHA256)
            && TranslationProvenanceValidator.isSHA(binding.attemptIdentitySHA256)
    }

    private static func validItem(
        _ item: TranslationHumanReviewPacketItem
    ) -> Bool {
        HumanReviewSignatureValidator.validItemID(item.itemID)
            && HumanReviewRequirementKind(rawValue: item.reviewKind) != nil
            && !item.reviewSubject.isEmpty
    }
}
