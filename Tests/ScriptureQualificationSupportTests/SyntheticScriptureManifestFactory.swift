import Foundation
import ScriptureAPI
import ScriptureQualificationSupport

enum SyntheticScriptureManifestFactory {
    static let now = Date(timeIntervalSince1970: 1_787_520_000)

    static func make(hashes: SyntheticScriptureHashes) -> ScriptureQualificationManifest {
        ScriptureQualificationManifest(
            schemaVersion: 1,
            corpusID: "synthetic-private-scripture-v1",
            createdAt: "2026-08-01T00:00:00Z",
            visibility: .gitignoredPrivateLocalQAOnly,
            mustNotCommit: true,
            editionPair: .production,
            grants: grants(hashes: hashes),
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

    private static func grants(
        hashes: SyntheticScriptureHashes
    ) -> [ScriptureQualificationGrant] {
        [
            grant(
                id: "english-grant",
                editionID: .englishStandardVersion2025,
                evidencePath: "evidence/english.txt",
                hash: hashes.englishEvidence
            ),
            grant(
                id: "chinese-grant",
                editionID: .newPunctuationCUVShenSimplified1988,
                evidencePath: "evidence/chinese.txt",
                hash: hashes.chineseEvidence
            ),
        ]
    }

    private static func grant(
        id: String,
        editionID: ScriptureEditionID,
        evidencePath: String,
        hash: String
    ) -> ScriptureQualificationGrant {
        .init(
            id: id,
            editionID: editionID,
            licensor: "Synthetic Rights Administrator",
            licensee: "Synthetic Test Church",
            agreementID: "synthetic-agreement",
            evidencePath: evidencePath,
            evidenceSHA256: hash,
            validFrom: "2026-01-01T00:00:00Z",
            expiresAt: "2027-01-01T00:00:00Z",
            territories: ["US"],
            reviewedBy: "Synthetic Reviewer",
            reviewedAt: "2026-07-01T00:00:00Z",
            rights: .init(
                textUseAuthorized: true,
                audioUseAuthorized: true,
                recordingUseAuthorized: true,
                asrEvaluationAuthorized: true,
                crossLanguageEvaluationAuthorized: true,
                modelTrainingAuthorized: false,
                redistributionAuthorized: false
            )
        )
    }

}

struct SyntheticScriptureHashes {
    let englishEvidence: String
    let chineseEvidence: String
    let audio: String
    let reference: String
}
