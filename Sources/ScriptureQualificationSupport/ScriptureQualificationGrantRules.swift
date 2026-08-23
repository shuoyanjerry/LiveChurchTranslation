import Foundation
import ScriptureAPI

enum ScriptureQualificationGrantRules {
    static func validate(_ grant: ScriptureQualificationGrant, now: Date) throws {
        try ScriptureQualificationScalarRules.requireID(grant.id, label: "grant.id")
        guard allowedEditions.contains(grant.editionID) else {
            throw ScriptureQualificationError.invalidManifest("grant has unsupported edition")
        }
        for (value, label) in [
            (grant.licensor, "grant.licensor"),
            (grant.licensee, "grant.licensee"),
            (grant.agreementID, "grant.agreementID"),
            (grant.reviewedBy, "grant.reviewedBy"),
        ] {
            try ScriptureQualificationScalarRules.requireText(value, label: label)
        }
        try ScriptureQualificationScalarRules.requireRelativePath(
            grant.evidencePath,
            label: "grant.evidencePath"
        )
        try ScriptureQualificationScalarRules.requireHash(
            grant.evidenceSHA256,
            label: "grant.evidenceSHA256"
        )
        try validateDates(grant, now: now)
        try validateTerritories(grant.territories)
    }

    private static func validateDates(
        _ grant: ScriptureQualificationGrant,
        now: Date
    ) throws {
        let validFrom = try ScriptureQualificationScalarRules.date(
            grant.validFrom,
            label: "grant.validFrom"
        )
        let reviewedAt = try ScriptureQualificationScalarRules.date(
            grant.reviewedAt,
            label: "grant.reviewedAt"
        )
        guard validFrom <= now, reviewedAt <= now else {
            throw ScriptureQualificationError.invalidManifest("grant is not yet valid or reviewed")
        }
        if let expiry = grant.expiresAt {
            let expiresAt = try ScriptureQualificationScalarRules.date(
                expiry,
                label: "grant.expiresAt"
            )
            guard expiresAt > now, expiresAt > validFrom else {
                throw ScriptureQualificationError.invalidManifest("grant is expired")
            }
        }
    }

    private static func validateTerritories(_ territories: [String]) throws {
        guard !territories.isEmpty else {
            throw ScriptureQualificationError.invalidManifest("grant territories must not be empty")
        }
        for territory in territories {
            try ScriptureQualificationScalarRules.requireText(
                territory,
                label: "grant.territories",
                maximum: 128
            )
        }
        guard Set(territories).count == territories.count else {
            throw ScriptureQualificationError.invalidManifest("grant territories must be unique")
        }
    }

    private static let allowedEditions: Set<ScriptureEditionID> = [
        .englishStandardVersion2025,
        .newPunctuationCUVShenSimplified1988,
    ]
}
