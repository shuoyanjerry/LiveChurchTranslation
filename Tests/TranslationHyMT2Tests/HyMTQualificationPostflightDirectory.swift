import Darwin
import Foundation
import TranslationQualificationSupport

enum HyMTQualificationPostflightDirectory {
    static func withDescriptor<Result>(
        workspaceRoot: URL,
        _ body: (Int32) throws -> Result
    ) throws -> Result {
        let rootURL = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        let root = Darwin.open(
            rootURL.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard root >= 0 else { throw storageFailure }
        defer { _ = close(root) }
        let artifacts = try openDirectory(".artifacts", parent: root)
        defer { _ = close(artifacts) }
        let reports = try openDirectory("translation-qualification", parent: artifacts)
        defer { _ = close(reports) }
        return try body(reports)
    }

    static func sidecarFilename(for reportFilename: String) throws -> String {
        try TranslationQualificationReportWriter.validatePrivateFilename(reportFilename)
        return reportFilename + ".postflight.json"
    }

    static var storageFailure: TranslationQualificationError {
        .writeFailed("postflight evidence storage failed")
    }

    private static func openDirectory(_ name: String, parent: Int32) throws -> Int32 {
        let descriptor = openat(
            parent,
            name,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else { throw storageFailure }
        return descriptor
    }
}
