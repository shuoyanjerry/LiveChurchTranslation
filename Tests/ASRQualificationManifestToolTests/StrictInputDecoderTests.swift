import Foundation
import Testing

@Suite struct StrictInputDecoderTests {
    @Test func rejectsUnknownVADField() throws {
        let data = try ManifestToolVADFixture.data { $0["legacy"] = true }

        expectError(.unexpectedField(path: "vad", field: "legacy")) {
            _ = try StrictInputDecoder.vadReport(data)
        }
    }

    @Test func rejectsMissingNestedVADField() throws {
        let data = try ManifestToolVADFixture.data { root in
            var environment = root["environment"] as? [String: Any] ?? [:]
            environment.removeValue(forKey: "repositoryRevision")
            root["environment"] = environment
        }

        expectError(
            .missingField(path: "vad.environment", field: "repositoryRevision")
        ) {
            _ = try StrictInputDecoder.vadReport(data)
        }
    }

    @Test func rejectsUnknownCorpusAndReferenceFields() throws {
        let corpus = try ManifestToolSourceFixture.corpusData { $0["audio_sha256"] = "bad" }
        let reference = try ManifestToolSourceFixture.referenceData { root in
            var clips = root["clips"] as? [[String: Any]] ?? []
            clips[0]["legacy"] = true
            root["clips"] = clips
        }

        expectError(.unexpectedField(path: "corpus", field: "audio_sha256")) {
            _ = try StrictInputDecoder.corpusManifest(corpus)
        }
        expectError(
            .unexpectedField(path: "reference.clips[0]", field: "legacy")
        ) {
            _ = try StrictInputDecoder.referenceManifest(reference)
        }
    }
}

private func expectError(
    _ expected: ManifestToolError,
    operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("Expected \(expected)")
    } catch let error as ManifestToolError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
