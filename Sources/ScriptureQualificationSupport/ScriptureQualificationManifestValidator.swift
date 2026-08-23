import Foundation
import ScriptureAPI

public struct ScriptureQualificationManifestValidator: Sendable {
    private let now: Date

    public init(now: Date = Date()) {
        self.now = now
    }

    public func validate(_ manifest: ScriptureQualificationManifest) throws {
        guard manifest.schemaVersion == 2 else {
            throw ScriptureQualificationError.invalidManifest("schemaVersion must be 2")
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
        let declarations = try validateDeclarations(manifest.sourceDeclarations)
        let items = try validateItems(manifest.items, declarations: declarations)
        let usedDeclarations = try ScriptureQualificationPairRules.validate(
            manifest.translationPairs,
            items: items
        )
        guard usedDeclarations == Set(declarations.keys) else {
            throw ScriptureQualificationError.invalidManifest(
                "every source declaration must be used"
            )
        }
    }

    private func validateDeclarations(
        _ values: [ScriptureQualificationSourceDeclaration]
    ) throws -> [String: ScriptureQualificationSourceDeclaration] {
        guard !values.isEmpty else {
            throw ScriptureQualificationError.invalidManifest(
                "sourceDeclarations must not be empty"
            )
        }
        var result: [String: ScriptureQualificationSourceDeclaration] = [:]
        for declaration in values {
            try ScriptureQualificationDeclarationRules.validate(declaration, now: now)
            guard result.updateValue(declaration, forKey: declaration.id) == nil else {
                throw ScriptureQualificationError.invalidManifest(
                    "duplicate source declaration id"
                )
            }
        }
        return result
    }

    private func validateItems(
        _ values: [ScriptureQualificationItem],
        declarations: [String: ScriptureQualificationSourceDeclaration]
    ) throws -> [String: ScriptureQualificationItem] {
        guard !values.isEmpty else {
            throw ScriptureQualificationError.invalidManifest("items must not be empty")
        }
        var result: [String: ScriptureQualificationItem] = [:]
        var paths = Set<String>()
        for item in values {
            try ScriptureQualificationItemRules.validate(item, declarations: declarations)
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
