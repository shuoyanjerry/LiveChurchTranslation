import Foundation
import ScriptureAPI

public struct ScriptureQualificationManifestValidator: Sendable {
    private let now: Date

    public init(now: Date = Date()) {
        self.now = now
    }

    public func validate(_ manifest: ScriptureQualificationManifest) throws {
        guard manifest.schemaVersion == 1 else {
            throw ScriptureQualificationError.invalidManifest("schemaVersion must be 1")
        }
        try ScriptureQualificationScalarRules.requireID(manifest.corpusID, label: "corpusID")
        let createdAt = try ScriptureQualificationScalarRules.date(
            manifest.createdAt,
            label: "createdAt"
        )
        guard createdAt <= now else {
            throw ScriptureQualificationError.invalidManifest("createdAt is in the future")
        }
        guard manifest.visibility == .gitignoredPrivateLocalQAOnly, manifest.mustNotCommit else {
            throw ScriptureQualificationError.invalidManifest(
                "corpus must be gitignored, private, local-QA-only, and mustNotCommit"
            )
        }
        guard manifest.editionPair == .production else {
            throw ScriptureQualificationError.invalidManifest(
                "editionPair must exactly equal ScriptureEditionPair.production"
            )
        }
        let grants = try validateGrants(manifest.grants)
        guard Set(grants.values.map(\.licensee)).count == 1 else {
            throw ScriptureQualificationError.invalidManifest(
                "all grants must name the same licensee"
            )
        }
        let items = try validateItems(manifest.items, grants: grants)
        let usedGrants = try ScriptureQualificationPairRules.validate(
            manifest.translationPairs,
            items: items
        )
        guard usedGrants == Set(grants.keys) else {
            throw ScriptureQualificationError.invalidManifest("every grant must be used")
        }
    }

    private func validateGrants(
        _ values: [ScriptureQualificationGrant]
    ) throws -> [String: ScriptureQualificationGrant] {
        guard !values.isEmpty else {
            throw ScriptureQualificationError.invalidManifest("grants must not be empty")
        }
        var result: [String: ScriptureQualificationGrant] = [:]
        for grant in values {
            try ScriptureQualificationGrantRules.validate(grant, now: now)
            guard result.updateValue(grant, forKey: grant.id) == nil else {
                throw ScriptureQualificationError.invalidManifest("duplicate grant id")
            }
        }
        return result
    }

    private func validateItems(
        _ values: [ScriptureQualificationItem],
        grants: [String: ScriptureQualificationGrant]
    ) throws -> [String: ScriptureQualificationItem] {
        guard !values.isEmpty else {
            throw ScriptureQualificationError.invalidManifest("items must not be empty")
        }
        var result: [String: ScriptureQualificationItem] = [:]
        var paths = Set<String>()
        for item in values {
            try ScriptureQualificationItemRules.validate(item, grants: grants)
            guard result.updateValue(item, forKey: item.id) == nil else {
                throw ScriptureQualificationError.invalidManifest("duplicate item id")
            }
            for path in [item.audioPath, item.referencePath] where !paths.insert(path).inserted {
                throw ScriptureQualificationError.invalidManifest("item file paths must be unique")
            }
        }
        return result
    }
}
