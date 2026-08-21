import Foundation
@testable import ModelDownloadHTTP
import ModelRuntimeAPI
import Testing

@Suite struct ManifestValidationTests {
    @Test func rejectsNonHTTPSArtifact() throws {
        let remoteURL = try #require(URL(string: "http://example.com/model.bin"))
        do {
            _ = try artifact(remoteURL: remoteURL)
            Issue.record("Expected insecure URL rejection")
        } catch let error as ModelManifestError {
            #expect(error == .insecureURL(remoteURL.absoluteString))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsTraversalAndInvalidDigest() throws {
        let remoteURL = try #require(URL(string: "https://example.com/model.bin"))
        do {
            _ = try artifact(remoteURL: remoteURL, relativePath: "tokenizer/../secret")
            Issue.record("Expected path traversal rejection")
        } catch let error as ModelManifestError {
            #expect(error == .invalidRelativePath("tokenizer/../secret"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        do {
            _ = try artifact(remoteURL: remoteURL, sha256: "not-a-sha")
            Issue.record("Expected invalid digest rejection")
        } catch let error as ModelManifestError {
            #expect(error == .invalidSHA256)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsDescriptorSizeMismatch() throws {
        let remoteURL = try #require(URL(string: "https://example.com/model.bin"))
        let item = try artifact(remoteURL: remoteURL, expectedBytes: 5)
        do {
            _ = try manifest(expectedBytes: 6, artifacts: [item])
            Issue.record("Expected descriptor size mismatch")
        } catch let error as ModelManifestError {
            #expect(error == .descriptorSizeMismatch)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsOverlappingArtifactPaths() throws {
        let remoteURL = try #require(URL(string: "https://example.com/model.bin"))
        let parent = try artifact(remoteURL: remoteURL, relativePath: "tokenizer")
        let child = try artifact(
            remoteURL: remoteURL,
            relativePath: "tokenizer/vocab.json",
            sha256: String(repeating: "b", count: 64)
        )
        do {
            _ = try manifest(expectedBytes: 2, artifacts: [parent, child])
            Issue.record("Expected overlapping path rejection")
        } catch let error as ModelManifestError {
            #expect(error == .conflictingArtifactPath)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func artifact(
        remoteURL: URL,
        relativePath: String = "model.bin",
        expectedBytes: Int64 = 1,
        sha256: String = String(repeating: "a", count: 64)
    ) throws -> ModelArtifactManifest {
        try ModelArtifactManifest(
            remoteURL: remoteURL,
            relativePath: relativePath,
            expectedBytes: expectedBytes,
            sha256: sha256
        )
    }

    private func manifest(
        expectedBytes: Int64,
        artifacts: [ModelArtifactManifest]
    ) throws -> ModelDownloadManifest {
        let descriptor = ModelDescriptor(
            id: ModelID(rawValue: "model"), displayName: "Model",
            version: "revision", expectedBytes: expectedBytes,
            sha256: nil, license: "Apache-2.0"
        )
        return try ModelDownloadManifest(
            descriptor: descriptor,
            installDirectoryName: "model",
            artifacts: artifacts,
            result: .directory
        )
    }
}
