import ASRQualificationSupport
import Foundation

extension QwenEnglishQualificationRunner {
    func makeReport(
        _ manifest: QwenEnglishCorpusManifest,
        manifestData: Data,
        results: [QwenEnglishClipResult]
    ) -> QwenEnglishQualificationReport {
        let aggregate = QwenEnglishAggregateResult(
            clipCount: results.count,
            voiceCount: Set(results.map(\.voice)).count,
            localeCount: Set(results.map(\.locale)).count,
            audioSeconds: results.map(\.audioSeconds).reduce(0, +),
            decodeSeconds: results.map(\.decodeSeconds).reduce(0, +),
            wordEdits: results.map(\.wordEdits).reduce(0, +),
            referenceWords: results.map(\.referenceWords).reduce(0, +),
            characterEdits: results.map(\.characterEdits).reduce(0, +),
            referenceCharacters: results.map(\.referenceCharacters).reduce(0, +)
        )
        return QwenEnglishQualificationReport(
            schemaVersion: 1,
            languageCode: "en",
            contextPrompt: Self.prompt,
            gate: Self.gate,
            modelRevision: QwenQualificationConfiguration.modelRevision,
            runtimeRevision: QwenQualificationConfiguration.runtimeRevision,
            corpusManifestSHA256: QwenQualificationHashing.sha256(manifestData),
            corpus: manifest,
            aggregate: aggregate,
            clips: results
        )
    }
}
