import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationCorpusLoaderTests {
    @Test func loadsStrictSyntheticCorpusAndAllHashes() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()

        #expect(corpus.manifest.segments.count == 100)
        #expect(corpus.manifest.summary.taGlyphOccurrenceCount == 98)
        #expect(corpus.manifestSHA256 == fixture.manifestSHA256)
        #expect(corpus.schemaSHA256 == fixture.schemaSHA256)
    }

    @Test func rejectsUnknownJSONKey() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let data = try Data(contentsOf: fixture.manifestURL)
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["unexpected"] = true
        let changed = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationQualificationManifestDecoder.decode(changed)
        }
    }

    @Test func rejectsDuplicateJSONKeyBeforeFoundationCollapsesIt() {
        let data = Data(#"{"schemaVersion": 1, "schemaVersion": 1}"#.utf8)

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationQualificationManifestDecoder.decode(data)
        }
    }

    @Test func rejectsSourceHashDrift() throws {
        let fixture = try SyntheticTranslationWorkspace()
        try Data("tampered".utf8).write(to: fixture.sourceAssetURL)

        #expect(throws: TranslationQualificationError.self) {
            _ = try fixture.load()
        }
    }

    @Test func rejectsNonTaMutationInObservedASRText() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let data = try Data(contentsOf: fixture.manifestURL)
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var segments = try #require(object["segments"] as? [[String: Any]])
        segments[1]["observedASRAmbiguousChinese"] = "他不在这里。"
        object["segments"] = segments
        let changed = try JSONSerialization.data(withJSONObject: object)
        let manifest = try TranslationQualificationManifestDecoder.decode(changed)

        #expect(throws: TranslationQualificationError.self) {
            try TranslationManifestValidator.validate(manifest)
        }
    }

}
