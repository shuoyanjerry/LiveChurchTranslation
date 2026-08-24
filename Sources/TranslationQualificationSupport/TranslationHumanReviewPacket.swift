import Foundation

public struct TranslationHumanReviewPacket: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let policyRevision: String
    public let reportFileSHA256: String
    public let postflightFileSHA256: String
    public let reportBinding: TranslationHumanReviewReportBinding
    public let items: [TranslationHumanReviewPacketItem]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case policyRevision
        case reportFileSHA256
        case postflightFileSHA256
        case reportBinding
        case items
    }
}

public struct TranslationHumanReviewPacketItem: Codable, Equatable, Sendable {
    public let itemID: String
    public let sourceText: String
    public let targetText: String
    public let referenceText: String
    public let reviewKind: String
    public let reviewSubject: String
    public let humanResolvable: Bool

    enum CodingKeys: String, CodingKey {
        case itemID
        case sourceText
        case targetText
        case referenceText
        case reviewKind
        case reviewSubject
        case humanResolvable
    }
}

extension TranslationHumanReviewEvidence {
    public static func makeReviewPacket(
        report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation,
        reportFileSHA256: String,
        postflightFileSHA256: String
    ) throws -> TranslationHumanReviewPacket {
        guard
            TranslationProvenanceValidator.isReleaseBound(report, expectation: expectation),
            isSHA(reportFileSHA256), isSHA(postflightFileSHA256)
        else {
            throw TranslationQualificationError.invalidReport(
                "human review packet inputs are not release-bound"
            )
        }
        let binding = try reportBinding(for: report)
        let requirements = try TranslationHumanReviewRequirements.derive(
            attempts: expectation.trustedAttempts,
            segments: expectation.corpus.manifest.segments,
            reportBinding: binding
        )
        let items = try makePacketItems(
            requirements,
            attempts: expectation.trustedAttempts
        )
        return TranslationHumanReviewPacket(
            schemaVersion: TranslationHumanReviewPacket.currentSchemaVersion,
            policyRevision: currentPolicyRevision,
            reportFileSHA256: reportFileSHA256,
            postflightFileSHA256: postflightFileSHA256,
            reportBinding: binding,
            items: items
        )
    }

    private static func makePacketItems(
        _ requirements: [TranslationHumanReviewRequirement],
        attempts trustedAttempts: [TranslationQualificationAttempt]
    ) throws -> [TranslationHumanReviewPacketItem] {
        let attempts = Dictionary(
            uniqueKeysWithValues: trustedAttempts.map { ($0.segmentID, $0) }
        )
        return try requirements.map { requirement in
            guard let attempt = attempts[requirement.identity.segmentID] else {
                throw TranslationQualificationError.invalidReport(
                    "human review packet attempt is missing"
                )
            }
            return TranslationHumanReviewPacketItem(
                itemID: requirement.itemID,
                sourceText: attempt.translationSourceText,
                targetText: attempt.hypothesisEnglish ?? "",
                referenceText: attempt.humanReferenceEnglish,
                reviewKind: requirement.identity.kind.rawValue,
                reviewSubject: requirement.identity.subject,
                humanResolvable: requirement.isHumanResolvable
            )
        }
    }

    public static func encodeReviewPacket(
        _ packet: TranslationHumanReviewPacket
    ) throws -> Data {
        try HumanReviewPacketValidator.validate(packet)
        return try canonicalData(packet)
    }

    @discardableResult
    public static func writePrivateReviewPacket(
        _ packet: TranslationHumanReviewPacket,
        workspaceRoot: URL,
        filename: String
    ) throws -> URL {
        try TranslationPrivateReportStorage(
            workspaceRoot: workspaceRoot,
            filename: filename
        ).write(try encodeReviewPacket(packet))
    }

    private static func isSHA(_ value: String) -> Bool {
        TranslationProvenanceValidator.isSHA(value)
    }
}
