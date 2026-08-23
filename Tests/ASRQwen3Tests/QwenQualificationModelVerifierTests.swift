import Foundation
import Testing

@Suite("Qwen qualification model verification")
struct QwenQualificationModelVerifierTests {
    @Test("accepts only exact bytes and SHA")
    func acceptsExactArtifact() throws {
        let fixture = try Fixture(data: Data("verified model".utf8))
        defer { fixture.remove() }

        try fixture.verifier.verify(directory: fixture.directory)
    }

    @Test("rejects a missing production artifact before model loading")
    func rejectsMissingArtifact() throws {
        let fixture = try Fixture(data: Data("verified model".utf8), writesFile: false)
        defer { fixture.remove() }

        #expect(throws: QwenQualificationModelVerificationError.missingFile("model.bin")) {
            try fixture.verifier.verify(directory: fixture.directory)
        }
    }

    @Test("rejects same-size mutated model bytes")
    func rejectsMutation() throws {
        let expected = Data("verified model".utf8)
        let fixture = try Fixture(data: expected)
        defer { fixture.remove() }
        try Data("tampered model".utf8).write(to: fixture.fileURL)

        #expect(throws: QwenQualificationModelVerificationError.sha256Mismatch("model.bin")) {
            try fixture.verifier.verify(directory: fixture.directory)
        }
    }
}

private struct Fixture {
    let directory: URL
    let fileURL: URL
    let verifier: QwenQualificationModelVerifier

    init(data: Data, writesFile: Bool = true) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        fileURL = directory.appendingPathComponent("model.bin")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        if writesFile { try data.write(to: fileURL) }
        verifier = QwenQualificationModelVerifier(
            artifacts: [
                QwenQualificationModelArtifact(
                    relativePath: "model.bin",
                    expectedBytes: Int64(data.count),
                    sha256: QwenQualificationHashing.sha256(data)
                )
            ]
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
