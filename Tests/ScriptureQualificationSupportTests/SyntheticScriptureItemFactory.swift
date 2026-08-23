import ScriptureAPI
import ScriptureQualificationSupport

enum SyntheticScriptureItemFactory {
    static func make(hashes: SyntheticScriptureHashes) -> [ScriptureQualificationItem] {
        specifications.map { specification in
            item(specification, hashes: hashes)
        }
    }

    private static func item(
        _ specification: SyntheticScriptureItemSpecification,
        hashes: SyntheticScriptureHashes
    ) -> ScriptureQualificationItem {
        let isEnglish = specification.language == "en"
        return .init(
            id: specification.id,
            editionID: specification.editionID,
            textDeclarationID: isEnglish ? "english-source" : "chinese-source",
            audioDeclarationID: isEnglish ? "english-source" : "chinese-source",
            useKind: .exactQuotation,
            partition: specification.partition,
            readingKind: .fullVerse,
            languageTag: specification.language,
            audioPath: "audio/\(specification.id).wav",
            audioSHA256: hashes.audio,
            referencePath: "reference/\(specification.id).txt",
            referenceSHA256: hashes.reference,
            bookID: .genesis,
            chapter: 1,
            verseStart: specification.verse,
            verseEnd: specification.verse,
            speakerID: "speaker-\(specification.id)",
            recordingEnvironment: "synthetic-test-room"
        )
    }

    private static let specifications: [SyntheticScriptureItemSpecification] = [
        .init(
            id: "en-development",
            editionID: .englishStandardVersion2025,
            language: "en",
            partition: .development,
            verse: 1
        ),
        .init(
            id: "zh-development",
            editionID: .newPunctuationCUVShenSimplified1988,
            language: "zh-Hans",
            partition: .development,
            verse: 1
        ),
        .init(
            id: "en-blind",
            editionID: .englishStandardVersion2025,
            language: "en",
            partition: .sealedBlindQualification,
            verse: 2
        ),
        .init(
            id: "zh-blind",
            editionID: .newPunctuationCUVShenSimplified1988,
            language: "zh-Hans",
            partition: .sealedBlindQualification,
            verse: 2
        ),
    ]
}

private struct SyntheticScriptureItemSpecification {
    let id: String
    let editionID: ScriptureEditionID
    let language: String
    let partition: ScriptureQualificationPartition
    let verse: Int
}
