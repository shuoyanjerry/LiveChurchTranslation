import ScriptureAPI

enum ScriptureQualificationItemRules {
    static func validate(
        _ item: ScriptureQualificationItem,
        grants: [String: ScriptureQualificationGrant]
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
        try requireTextGrant(item, grants: grants)
        try requireAudioGrant(item, grants: grants)
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

    private static func requireTextGrant(
        _ item: ScriptureQualificationItem,
        grants: [String: ScriptureQualificationGrant]
    ) throws {
        guard let grant = grants[item.textGrantID], grant.editionID == item.editionID else {
            throw ScriptureQualificationError.invalidManifest("missing matching item text grant")
        }
        guard
            grant.rights.textUseAuthorized,
            grant.rights.crossLanguageEvaluationAuthorized
        else {
            throw ScriptureQualificationError.invalidManifest(
                "text grant lacks text or cross-language evaluation rights"
            )
        }
    }

    private static func requireAudioGrant(
        _ item: ScriptureQualificationItem,
        grants: [String: ScriptureQualificationGrant]
    ) throws {
        guard let grant = grants[item.audioGrantID], grant.editionID == item.editionID else {
            throw ScriptureQualificationError.invalidManifest("missing matching item audio grant")
        }
        guard
            grant.rights.audioUseAuthorized,
            grant.rights.recordingUseAuthorized,
            grant.rights.asrEvaluationAuthorized
        else {
            throw ScriptureQualificationError.invalidManifest(
                "audio grant lacks audio, recording, or ASR-evaluation rights"
            )
        }
    }

    private static let languages: [ScriptureEditionID: String] = [
        .englishStandardVersion2025: "en",
        .newPunctuationCUVShenSimplified1988: "zh-Hans",
    ]
}
