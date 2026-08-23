import ASRAPI
import CryptoKit
import Foundation

/// Verifies the complete pinned challenger snapshot before native initialization.
public struct FunASRNanoModelVerifier: Sendable {
    private let artifacts: [FunASRNanoModelArtifact]

    public init() {
        artifacts = FunASRNanoModelArtifact.required
    }

    init(artifacts: [FunASRNanoModelArtifact]) {
        self.artifacts = artifacts
    }

    public func verify(directory: URL) throws {
        for artifact in artifacts {
            try verify(artifact, in: directory)
        }
    }

    private func verify(
        _ artifact: FunASRNanoModelArtifact,
        in directory: URL
    ) throws {
        let url = directory.appending(path: artifact.relativePath)
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [
                .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
            ])
        } catch {
            throw failure(artifact, reason: "missing")
        }
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw failure(artifact, reason: "invalid type")
        }
        guard values.fileSize == artifact.byteCount else {
            throw failure(artifact, reason: "invalid byte count")
        }
        guard try sha256(url) == artifact.sha256 else {
            throw failure(artifact, reason: "invalid SHA-256")
        }
    }

    private func sha256(_ url: URL) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw ASRError.inferenceFailed("A Fun-ASR-Nano artifact is unreadable.")
        }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func failure(
        _ artifact: FunASRNanoModelArtifact,
        reason: String
    ) -> ASRError {
        .inferenceFailed(
            "The Fun-ASR-Nano artifact \(artifact.relativePath) has \(reason)."
        )
    }
}
