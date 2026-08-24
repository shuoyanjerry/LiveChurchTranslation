import Foundation
import Testing

@Suite struct HyMTAdjudicationSecurityStaticTests {
    @Test func readinessFollowsFinalSnapshotChecks() throws {
        let adjudication = try source("HyMTQualificationAdjudicationTests.swift")
        let gate = try #require(adjudication.range(of: "requireAttestedReleaseReadyGates"))
        let frozen = try #require(
            adjudication.range(
                of: "try frozen.requireUnchanged()",
                range: gate.upperBound..<adjudication.endIndex
            )
        )
        let review = try #require(
            adjudication.range(
                of: "try review.requireUnchanged()",
                range: frozen.upperBound..<adjudication.endIndex
            )
        )
        let output = try #require(
            adjudication.range(of: "HyMTAdjudicationOutput.printEvidence")
        )
        #expect(output.lowerBound > review.lowerBound)
    }

    @Test func readinessIsTheLastEvidenceLine() throws {
        let output = try source("HyMTAdjudicationOutput.swift")
        let sidecar = try #require(output.range(of: "HUMAN_REVIEW_SIDECAR_SHA256"))
        let ready = try #require(output.range(of: "RELEASE_READY=true"))
        #expect(ready.lowerBound > sidecar.lowerBound)
        #expect(output.components(separatedBy: "RELEASE_READY=true").count == 2)
    }

    @Test func privateEvidenceMustBelongToCurrentUser() throws {
        #expect(try source("HyMTQualificationPrivateFile.swift").contains("st_uid == geteuid()"))
        #expect(try source("HyMTQualificationReportSnapshot.swift").contains("st_uid == geteuid()"))
    }

    private func source(_ filename: String) throws -> String {
        try String(contentsOf: directory.appendingPathComponent(filename), encoding: .utf8)
    }

    private var directory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }
}
