import ASRQualificationSupport
import Foundation
import Testing

@Suite struct ManifestDecoderTests {
    private let decoder = ASRQualificationManifestDecoder()

    @Test func decodesExactCodableRoundTrip() throws {
        let manifest = testManifest()
        let decoded = try decoder.decode(encoded(manifest))

        #expect(decoded == manifest)
    }

    @Test func readsManifestFromURL() throws {
        let url = try temporaryWAV(encoded(testManifest()))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try decoder.decode(contentsOf: url) == testManifest())
    }

    @Test func factoryFixesSchemaAndValidates() throws {
        let manifest = try ASRQualificationManifestFactory.make(
            corpusID: "public-domain-mandarin-scripture-v1",
            provenance: testProvenance(),
            clips: [testClip()]
        )

        #expect(manifest.schemaVersion == 2)
        #expect(manifest.clips.count == 1)
    }

    @Test func rejectsUnknownRootField() throws {
        let data = try mutateRoot { $0["legacy"] = true }

        awaitError(.unexpectedField(path: "$", field: "legacy"), data: data)
    }

    @Test func rejectsUnknownProvenanceField() throws {
        let data = try mutateRoot { root in
            var provenance = try requireObject(root["provenance"])
            provenance["vadSeconds"] = 1
            root["provenance"] = provenance
        }

        awaitError(
            .unexpectedField(path: "provenance", field: "vadSeconds"),
            data: data
        )
    }

    @Test func rejectsUnknownClipField() throws {
        let data = try mutateRoot { root in
            var clips = try requireArray(root["clips"])
            var clip = try requireObject(clips[0])
            clip["audioPath"] = "legacy.wav"
            clips[0] = clip
            root["clips"] = clips
        }

        awaitError(
            .unexpectedField(path: "clips[0]", field: "audioPath"),
            data: data
        )
    }

    @Test func rejectsUnknownSegmentField() throws {
        let data = try mutateRoot { root in
            var clips = try requireArray(root["clips"])
            var clip = try requireObject(clips[0])
            var segments = try requireArray(clip["segments"])
            var segment = try requireObject(segments[0])
            segment["endMilliseconds"] = 1
            segments[0] = segment
            clip["segments"] = segments
            clips[0] = clip
            root["clips"] = clips
        }

        awaitError(
            .unexpectedField(
                path: "clips[0].segments[0]",
                field: "endMilliseconds"
            ),
            data: data
        )
    }

    @Test func rejectsMissingAndWrongTypeFields() throws {
        let missing = try mutateRoot { $0.removeValue(forKey: "corpusID") }
        let wrongType = try mutateRoot { $0["schemaVersion"] = "2" }
        let missingPolicy = try mutateRoot { root in
            var clips = try requireArray(root["clips"])
            var clip = try requireObject(clips[0])
            clip.removeValue(forKey: "allowsHypothesisEdgeInsertions")
            clips[0] = clip
            root["clips"] = clips
        }

        awaitError(.malformedManifest, data: missing)
        awaitError(.malformedManifest, data: wrongType)
        awaitError(.malformedManifest, data: missingPolicy)
    }

    @Test func rejectsUnsupportedSchemaAfterDecoding() throws {
        let data = try encoded(testManifest(schemaVersion: 1))

        awaitError(.unsupportedSchemaVersion(1), data: data)
    }

    private func awaitError(_ expected: ASRQualificationError, data: Data) {
        do {
            _ = try decoder.decode(data)
            Issue.record("Expected \(expected)")
        } catch let error as ASRQualificationError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func mutateRoot(
        _ mutation: (inout [String: Any]) throws -> Void
    ) throws -> Data {
        var root = try requireObject(
            JSONSerialization.jsonObject(with: encoded(testManifest()))
        )
        try mutation(&root)
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }
}

private func requireObject(_ value: Any?) throws -> [String: Any] {
    guard let object = value as? [String: Any] else {
        throw ASRQualificationError.malformedManifest
    }
    return object
}

private func requireArray(_ value: Any?) throws -> [Any] {
    guard let array = value as? [Any] else {
        throw ASRQualificationError.malformedManifest
    }
    return array
}
