import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationReportSymlinkTests {
    @Test func rejectsArtifactDirectorySymlink() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let values = try reportValues(fixture)
        let root = try temporaryDirectory()
        let outside = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent(".artifacts"),
            withDestinationURL: outside
        )

        #expect(throws: TranslationQualificationError.self) {
            try TranslationQualificationReportWriter.writePrivate(
                values.report,
                releaseExpectation: values.expectation,
                workspaceRoot: root,
                filename: "report.json"
            )
        }
        let target = outside.appendingPathComponent("report.json")
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test func rejectsDestinationSymlinkWithoutChangingTarget() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let values = try reportValues(fixture)
        let directory = fixture.root.appendingPathComponent(
            ".artifacts/translation-qualification",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let outside = fixture.root.appendingPathComponent("outside.txt")
        try Data("unchanged".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("report.json"),
            withDestinationURL: outside
        )

        #expect(throws: TranslationQualificationError.self) {
            try TranslationQualificationReportWriter.writePrivate(
                values.report,
                releaseExpectation: values.expectation,
                workspaceRoot: fixture.root,
                filename: "report.json"
            )
        }
        #expect(try String(contentsOf: outside, encoding: .utf8) == "unchanged")
    }

    private func reportValues(
        _ fixture: SyntheticTranslationWorkspace
    ) throws -> WriterReportValues {
        let corpus = try fixture.load()
        return WriterReportValues(
            report: try SyntheticTranslationReportFactory.build(corpus: corpus),
            expectation: try SyntheticTranslationReportFactory.releaseExpectation(corpus: corpus)
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private struct WriterReportValues {
    let report: TranslationQualificationReport
    let expectation: TranslationReleaseExpectation
}
