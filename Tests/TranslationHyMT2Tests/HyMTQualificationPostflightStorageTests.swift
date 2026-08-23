import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HyMTQualificationPostflightStorageTests {
    @Test func writesOnlyFixedPrivateFieldsAndNeverOverwrites() throws {
        let workspace = try HyMTPostflightTestFixture.temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let fixture = try HyMTPostflightTestFixture.make()
        let attestation = try HyMTQualificationPostflightValidator.validate(
            snapshot: fixture.snapshot,
            corpus: fixture.corpus,
            provenance: fixture.provenance,
            configuration: fixture.configuration,
            timestamp: "2026-08-22T13:00:00Z"
        )

        let url = try HyMTQualificationPostflightWriter.writePrivate(
            attestation,
            workspaceRoot: workspace,
            reportFilename: "synthetic-report.json"
        )
        #expect(url.lastPathComponent == "synthetic-report.json.postflight.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        #expect(Set(object.keys) == expectedKeys)
        #expect(object["postflightVerified"] as? Bool == true)
        #expect(throws: TranslationQualificationError.self) {
            try HyMTQualificationPostflightWriter.writePrivate(
                attestation,
                workspaceRoot: workspace,
                reportFilename: "synthetic-report.json"
            )
        }
    }

    @Test func snapshotRejectsSymlinksAndDetectsPersistentChange() throws {
        let workspace = try HyMTPostflightTestFixture.temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let reports = workspace.appendingPathComponent(".artifacts/translation-qualification")
        let report = reports.appendingPathComponent("diagnostic.json")
        try Data("synthetic-report-a".utf8).write(to: report, options: .withoutOverwriting)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: report.path
        )
        let snapshot = try HyMTQualificationReportSnapshot.load(
            workspaceRoot: workspace,
            reportFilename: report.lastPathComponent
        )
        try Data("synthetic-report-b".utf8).write(to: report, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: report.path
        )
        #expect(throws: TranslationQualificationError.self) {
            try snapshot.requireUnchanged(
                workspaceRoot: workspace,
                reportFilename: report.lastPathComponent
            )
        }

        let link = reports.appendingPathComponent("linked.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: report)
        #expect(throws: TranslationQualificationError.self) {
            try HyMTQualificationReportSnapshot.load(
                workspaceRoot: workspace,
                reportFilename: link.lastPathComponent
            )
        }
    }

    private let expectedKeys = Set([
        "schemaVersion", "reportSHA256", "sourceBundleSHA256",
        "testExecutableSHA256", "modelSHA256", "helperSHA256",
        "runtimeBundleSHA256", "configurationSHA256", "manifestSHA256",
        "schemaSHA256", "postflightTimestamp", "postflightVerified",
    ])
}
