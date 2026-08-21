import CryptoKit
import Foundation

struct ArtifactVerifier: Sendable {
    func isValid(_ url: URL, artifact: ModelArtifactManifest) async throws -> Bool {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return false }
        let attributes = try manager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
            let size = attributes[.size] as? NSNumber,
            size.int64Value == artifact.expectedBytes
        else { return false }
        return try await sha256(of: url) == artifact.sha256
    }

    private func sha256(of url: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while true {
            try Task.checkCancellation()
            guard let data = try handle.read(upToCount: 1_048_576), !data.isEmpty else {
                break
            }
            digest.update(data: data)
            await Task.yield()
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
