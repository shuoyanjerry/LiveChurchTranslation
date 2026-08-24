import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HyMTFreezeRequestStorageTests {
    @Test func writesCanonicalPrivateRequestWithoutReleaseAuthority() throws {
        let workspace = try HyMTPostflightTestFixture.temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let fixture = try HyMTPostflightTestFixture.make()
        let statement = try TranslationQualificationFreezeEvidence.makeStatement(
            report: fixture.report,
            artifacts: TranslationFreezeArtifactIdentity(
                reportFilename: "synthetic-report.json",
                reportSHA256: fixture.snapshot.sha256,
                postflightFilename: "synthetic-report.json.postflight.json",
                postflightSHA256: sha("8"),
                reviewPacketFilename: "synthetic-report.review-packet.json",
                reviewPacketSHA256: sha("9")
            ),
            frozenAt: "2026-08-24T12:00:00Z",
            requestID: "C2C3E98D-4085-4BBE-B3E7-CDE3ED84D735"
        )
        let data = try TranslationQualificationFreezeEvidence.encodeStatement(statement)
        let url = try HyMTQualificationPostflightWriter.writePrivate(
            data,
            workspaceRoot: workspace,
            filename: "synthetic-report.freeze-request.json"
        )

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(try TranslationQualificationFreezeEvidence.decodeStatement(from: data) == statement)
        #expect(throws: TranslationQualificationError.self) {
            try HyMTQualificationPostflightWriter.writePrivate(
                data,
                workspaceRoot: workspace,
                filename: "synthetic-report.freeze-request.json"
            )
        }
    }

    private func sha(_ character: Character) -> String {
        String(repeating: character, count: 64)
    }
}
