import Foundation
import ModelDownloadAPI
import Testing

enum ExpectedModelDownloadError {
    case cancelled
    case invalidArtifact
}

@MainActor
func expectModelDownloadError(
    _ expected: ExpectedModelDownloadError,
    operation: () async throws -> URL
) async {
    do {
        _ = try await operation()
        Issue.record("Expected model download failure.")
    } catch let error as ModelDownloadError {
        guard matches(error, expected: expected) else {
            Issue.record("Unexpected model download error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

func expectNoPublishedArtifact(at fileURL: URL) {
    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    #expect(!FileManager.default.fileExists(atPath: fileURL.path + ".part"))
}

private func matches(
    _ error: ModelDownloadError,
    expected: ExpectedModelDownloadError
) -> Bool {
    switch (error, expected) {
    case (.cancelled, .cancelled), (.invalidArtifact, .invalidArtifact): true
    default: false
    }
}
