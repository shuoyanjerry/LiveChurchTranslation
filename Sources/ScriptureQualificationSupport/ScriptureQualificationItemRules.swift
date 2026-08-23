import ScriptureAPI

enum ScriptureQualificationItemRules {
    static func validate(
        _ item: ScriptureQualificationItem,
        declarations: [String: ScriptureQualificationSourceDeclaration]
    ) throws {
        try ScriptureQualificationScalarRules.requireID(item.id, label: "item.id")
        guard item.useKind == .exactQuotation else {
            throw ScriptureQualificationError.invalidManifest(
                "qualification items must use exactQuotation"
            )
        }
        guard let expectedLanguage = languages[item.editionID], item.languageTag == expectedLanguage else {
            throw ScriptureQualificationError.invalidManifest("item language/edition mismatch")
        }
        try requireTextDeclaration(item, declarations: declarations)
        try requireAudioDeclaration(item, declarations: declarations)
        try ScriptureQualificationScalarRules.requireRelativePath(
            item.audioPath,
            label: "item.audioPath"
        )
        try ScriptureQualificationScalarRules.requireHash(
            item.audioSHA256,
            label: "item.audioSHA256"
        )
        try ScriptureQualificationScalarRules.requireRelativePath(
            item.referencePath,
            label: "item.referencePath"
        )
        try ScriptureQualificationScalarRules.requireHash(
            item.referenceSHA256,
            label: "item.referenceSHA256"
        )
        guard item.chapter > 0, item.verseStart > 0, item.verseEnd >= item.verseStart else {
            throw ScriptureQualificationError.invalidManifest("invalid item verse range")
        }
        try ScriptureQualificationScalarRules.requireID(item.speakerID, label: "item.speakerID")
        try ScriptureQualificationScalarRules.requireText(
            item.recordingEnvironment,
            label: "item.recordingEnvironment"
        )
    }

    private static func requireTextDeclaration(
        _ item: ScriptureQualificationItem,
        declarations: [String: ScriptureQualificationSourceDeclaration]
    ) throws {
        guard
            let declaration = declarations[item.textDeclarationID],
            declaration.editionID == item.editionID
        else {
            throw ScriptureQualificationError.invalidManifest(
                "missing matching item text source declaration"
            )
        }
        guard
            declaration.permittedUses.textEvaluationAllowed,
            declaration.permittedUses.crossLanguageEvaluationAllowed,
            declaration.permittedUses.modelAdjustmentAllowed
        else {
            throw ScriptureQualificationError.invalidManifest(
                "text source declaration does not allow required evaluation uses"
            )
        }
    }

    private static func requireAudioDeclaration(
        _ item: ScriptureQualificationItem,
        declarations: [String: ScriptureQualificationSourceDeclaration]
    ) throws {
        guard
            let declaration = declarations[item.audioDeclarationID],
            declaration.editionID == item.editionID
        else {
            throw ScriptureQualificationError.invalidManifest(
                "missing matching item audio source declaration"
            )
        }
        guard
            declaration.permittedUses.audioEvaluationAllowed,
            declaration.permittedUses.recordingEvaluationAllowed,
            declaration.permittedUses.asrEvaluationAllowed,
            declaration.permittedUses.modelAdjustmentAllowed
        else {
            throw ScriptureQualificationError.invalidManifest(
                "audio source declaration does not allow required evaluation uses"
            )
        }
    }

    private static let languages: [ScriptureEditionID: String] = [
        .englishStandardVersion2025: "en",
        .newPunctuationCUVShenSimplified1988: "zh-Hans",
    ]
}
