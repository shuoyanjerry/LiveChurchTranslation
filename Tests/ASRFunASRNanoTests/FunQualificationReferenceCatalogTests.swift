import ASRQualificationSupport
import Foundation
import Testing

@Suite("Fun-ASR qualification references")
struct FunQualificationReferenceCatalogTests {
    @Test func verifiesRawProvenanceAndKeepsPolicyInManifestV2() throws {
        let data = referenceData()
        let manifest = qualificationManifest(referenceData: data)

        let catalog = try FunQualificationReferenceCatalog.load(
            data: data,
            for: manifest
        )

        #expect(catalog.referencesByID == ["clip": "圣灵"])
        #expect(manifest.clips[0].allowsHypothesisEdgeInsertions)
    }

    @Test func rejectsRawReferenceManifestMutation() {
        let original = referenceData()
        let manifest = qualificationManifest(referenceData: original)
        var mutated = original
        mutated.append(0x20)

        #expect(throws: FunQualificationReferenceError.sha256Mismatch) {
            try FunQualificationReferenceCatalog.load(data: mutated, for: manifest)
        }
    }

    @Test func rejectsReferenceTextHashMismatch() {
        let data = referenceData()
        let manifest = qualificationManifest(
            referenceData: data,
            referenceTextSHA256: String(repeating: "0", count: 64)
        )

        #expect(throws: FunQualificationReferenceError.referenceSHA256Mismatch("clip")) {
            try FunQualificationReferenceCatalog.load(data: data, for: manifest)
        }
    }

    private func referenceData() -> Data {
        let header = #"{"schema_version":1,"corpus_id":"corpus","clips":["#
        let clip = #"{"id":"clip","reference_text":"圣灵","asr_ignore_hypothesis_edges":false}"#
        return Data((header + clip + "]}").utf8)
    }

    private func qualificationManifest(
        referenceData: Data,
        referenceTextSHA256: String? = nil
    ) -> ASRQualificationManifestV2 {
        let hash = String(repeating: "a", count: 64)
        let clip = ASRQualificationClipV2(
            id: "clip",
            audioSHA256: hash,
            sampleRate: 16_000,
            totalSamples: 16_000,
            referenceSHA256: referenceTextSHA256
                ?? FunQualificationHashing.sha256(Data("圣灵".utf8)),
            allowsHypothesisEdgeInsertions: true,
            segments: []
        )
        return ASRQualificationManifestV2(
            schemaVersion: 2,
            corpusID: "corpus",
            provenance: ASRQualificationProvenanceV2(
                sourceVADReportSHA256: hash,
                sourceVADStrategy: "fixture",
                sourceVADConfigurationSHA256: hash,
                sourceReferenceManifestSHA256: FunQualificationHashing.sha256(referenceData),
                sourceCorpusManifestSHA256: hash,
                generatorRevision: "fixture"
            ),
            clips: [clip]
        )
    }
}
