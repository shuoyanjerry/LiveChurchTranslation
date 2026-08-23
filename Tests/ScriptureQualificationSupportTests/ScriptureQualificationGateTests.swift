import Foundation
import ScriptureQualificationSupport
import Testing

@Suite struct ScriptureQualificationGateTests {
    @Test func loadsOnlyHashedPrivateExactEditionCorpus() throws {
        let fixture = try SyntheticScriptureCorpusFixture()

        let corpus = try fixture.load()

        #expect(corpus.manifest.editionPair == .production)
        #expect(corpus.grants.count == 2)
        #expect(corpus.items.count == 4)
        #expect(corpus.items.allSatisfy { $0.audioURL.path.hasPrefix(fixture.root.path + "/") })
        #expect(corpus.items.allSatisfy { $0.referenceURL.path.hasPrefix(fixture.root.path + "/") })
    }

    @Test func rejectsManifestWithoutExternallyExpectedHash() throws {
        let fixture = try SyntheticScriptureCorpusFixture()

        #expect(throws: ScriptureQualificationError.self) {
            _ = try ScriptureQualificationCorpusLoader.load(
                manifestURL: fixture.manifestURL,
                privateRoot: fixture.root,
                expectedManifestSHA256: String(repeating: "0", count: 64),
                now: SyntheticScriptureManifestFactory.now
            )
        }
    }

    @Test func rejectsEditionDescriptorDriftEvenWhenIDMatches() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        var editionPair = try #require(object["editionPair"] as? [String: Any])
        var english = try #require(editionPair["english"] as? [String: Any])
        english["fullName"] = "Lookalike edition"
        editionPair["english"] = english
        object["editionPair"] = editionPair
        try fixture.writeManifestObject(object)

        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
    }

    @Test func rejectsMissingASREvaluationRight() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        var grants = try #require(object["grants"] as? [[String: Any]])
        var rights = try #require(grants[0]["rights"] as? [String: Any])
        rights["asrEvaluationAuthorized"] = false
        grants[0]["rights"] = rights
        object["grants"] = grants
        try fixture.writeManifestObject(object)

        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
    }

    @Test func rejectsGrantsForDifferentLicensees() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        var grants = try #require(object["grants"] as? [[String: Any]])
        grants[1]["licensee"] = "Different Organization"
        object["grants"] = grants
        try fixture.writeManifestObject(object)

        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
    }

    @Test func rejectsCorpusWithoutSealedBlindPartition() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        var items = try #require(object["items"] as? [[String: Any]])
        for index in items.indices {
            items[index]["partition"] = "development"
        }
        object["items"] = items
        try fixture.writeManifestObject(object)

        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
    }

    @Test func rejectsPairedReadingKindMismatch() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        var items = try #require(object["items"] as? [[String: Any]])
        let index = try #require(items.firstIndex { $0["id"] as? String == "zh-development" })
        items[index]["readingKind"] = "partialVerse"
        object["items"] = items
        try fixture.writeManifestObject(object)

        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
    }

    @Test func rejectsTamperedEvidenceAndSymlinkedEvidence() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        let evidence = fixture.root.appendingPathComponent("evidence/english.txt")
        try Data("changed evidence".utf8).write(to: evidence)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: evidence.path
        )
        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }

        try FileManager.default.removeItem(at: evidence)
        try FileManager.default.createSymbolicLink(
            at: evidence,
            withDestinationURL: fixture.root.appendingPathComponent("evidence/chinese.txt")
        )
        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
    }

    @Test func rejectsUnknownAndDuplicateJSONFields() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        object["unreviewed"] = true
        try fixture.writeManifestObject(object)
        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }

        let duplicate = Data(#"{"schemaVersion":1,"schemaVersion":1}"#.utf8)
        #expect(throws: ScriptureQualificationError.self) {
            _ = try ScriptureQualificationManifestDecoder.decode(duplicate)
        }
    }
}
