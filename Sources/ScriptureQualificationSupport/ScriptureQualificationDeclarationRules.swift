import Foundation
import ScriptureAPI

enum ScriptureQualificationDeclarationRules {
    static func validate(
        _ declaration: ScriptureQualificationSourceDeclaration,
        now: Date
    ) throws {
        try validateIdentity(declaration)
        try validateDeclarationFile(declaration)
        try validateDate(declaration.declaredAt, now: now)
        try validateUseBoundary(declaration.permittedUses)
    }

    private static func validateIdentity(
        _ declaration: ScriptureQualificationSourceDeclaration
    ) throws {
        try ScriptureQualificationScalarRules.requireID(
            declaration.id,
            label: "sourceDeclaration.id"
        )
        guard allowedEditions.contains(declaration.editionID) else {
            throw ScriptureQualificationError.invalidManifest(
                "source declaration has unsupported edition"
            )
        }
        try ScriptureQualificationScalarRules.requireText(
            declaration.sourceAttribution,
            label: "sourceDeclaration.sourceAttribution",
            maximum: 1_024
        )
        try ScriptureQualificationScalarRules.requireText(
            declaration.declaredBy,
            label: "sourceDeclaration.declaredBy"
        )
    }

    private static func validateDeclarationFile(
        _ declaration: ScriptureQualificationSourceDeclaration
    ) throws {
        try ScriptureQualificationScalarRules.requireRelativePath(
            declaration.declarationPath,
            label: "sourceDeclaration.declarationPath"
        )
        try ScriptureQualificationScalarRules.requireHash(
            declaration.declarationSHA256,
            label: "sourceDeclaration.declarationSHA256"
        )
    }

    private static func validateDate(_ value: String, now: Date) throws {
        let declaredAt = try ScriptureQualificationScalarRules.date(
            value,
            label: "sourceDeclaration.declaredAt"
        )
        guard declaredAt <= now else {
            throw ScriptureQualificationError.invalidManifest(
                "source declaration date is in the future"
            )
        }
    }

    private static func validateUseBoundary(
        _ uses: ScriptureQualificationPermittedUses
    ) throws {
        guard
            !uses.modelTrainingAllowed,
            !uses.redistributionAllowed
        else {
            throw ScriptureQualificationError.invalidManifest(
                "qualification sources must prohibit model training and redistribution"
            )
        }
    }

    private static let allowedEditions: Set<ScriptureEditionID> = [
        .englishStandardVersion2025,
        .newPunctuationCUVShenSimplified1988,
    ]
}
