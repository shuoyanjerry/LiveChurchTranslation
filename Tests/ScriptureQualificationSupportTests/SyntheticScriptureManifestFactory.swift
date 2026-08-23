import Foundation
import ScriptureAPI
import ScriptureQualificationSupport

enum SyntheticScriptureManifestFactory {
    static let now = Date(timeIntervalSince1970: 1_787_520_000)

    static func make(hashes: SyntheticScriptureHashes) -> ScriptureQualificationManifest {
        ScriptureQualificationManifest(
            schemaVersion: 2,
            corpusID: "synthetic-private-scripture-v2",
            createdAt: "2026-08-01T00:00:00Z",
            visibility: .gitignoredPrivateLocalQAOnly,
            mustNotCommit: true,
            editionPair: .production,
            sourceDeclarations: declarations(hashes: hashes),
            items: SyntheticScriptureItemFactory.make(hashes: hashes),
            translationPairs: [
                .init(
                    id: "development-pair",
                    englishItemID: "en-development",
                    simplifiedChineseItemID: "zh-development"
                ),
                .init(
                    id: "blind-pair",
                    englishItemID: "en-blind",
                    simplifiedChineseItemID: "zh-blind"
                ),
            ]
        )
    }

    private static func declarations(
        hashes: SyntheticScriptureHashes
    ) -> [ScriptureQualificationSourceDeclaration] {
        [
            declaration(
                id: "english-source",
                editionID: .englishStandardVersion2025,
                path: "declarations/english.txt",
                hash: hashes.englishDeclaration
            ),
            declaration(
                id: "chinese-source",
                editionID: .newPunctuationCUVShenSimplified1988,
                path: "declarations/chinese.txt",
                hash: hashes.chineseDeclaration
            ),
        ]
    }

    private static func declaration(
        id: String,
        editionID: ScriptureEditionID,
        path: String,
        hash: String
    ) -> ScriptureQualificationSourceDeclaration {
        .init(
            id: id,
            editionID: editionID,
            sourceAttribution: "Original synthetic test source",
            declaredBy: "Synthetic Test Project",
            declarationPath: path,
            declarationSHA256: hash,
            declaredAt: "2026-07-01T00:00:00Z",
            permittedUses: .init(
                textEvaluationAllowed: true,
                audioEvaluationAllowed: true,
                recordingEvaluationAllowed: true,
                asrEvaluationAllowed: true,
                crossLanguageEvaluationAllowed: true,
                modelAdjustmentAllowed: true,
                modelTrainingAllowed: false,
                redistributionAllowed: false
            )
        )
    }

}

struct SyntheticScriptureHashes {
    let englishDeclaration: String
    let chineseDeclaration: String
    let audio: String
    let reference: String
}
