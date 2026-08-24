import Foundation
import Testing

@Suite struct HyMTQualificationDriverStaticTests {
    @Test func driverPreservesQualificationStatusAndAlwaysRunsPostflight() throws {
        let script = try String(
            contentsOf: workspaceRoot.appendingPathComponent(
                "Scripts/run_hymt_bilingual_qualification.sh"
            ),
            encoding: .utf8
        )
        let bootstrap = try bootstrapFunction(in: script)

        #expect(bootstrap.contains("TRANSLATION_QUALIFICATION_BOOTSTRAP=1"))
        #expect(bootstrap.contains("swift test -c release"))
        #expect(bootstrap.contains("--filter HyMTProvenanceBootstrapTests"))
        #expect(bootstrap.contains("-Xswiftc -warnings-as-errors"))
        #expect(!bootstrap.contains("--skip-build"))
        #expect(!script.contains("--filter HyMTQualificationProvenanceBootstrapTests"))
        #expect(!script.contains("swift build -c release --build-tests"))
        #expect(script.components(separatedBy: "swift test -c release --skip-build").count == 4)
        #expect(script.contains("TRANSLATION_QUALIFICATION_ADJUDICATE=1"))
        #expect(script.contains("--filter HyMTQualificationAdjudicationTests"))
        #expect(script.contains("BILINGUAL_TRANSLATION_FREEZE_ATTESTATION"))
        #expect(script.contains("legacy caller-provided trust hashes are not accepted"))
        #expect(script.contains("BILINGUAL_TRANSLATION_REVIEW_PACKET"))
        #expect(script.contains("BILINGUAL_TRANSLATION_FREEZE_REQUEST"))
        #expect(script.contains("qualification_status=$?"))
        #expect(script.contains("TRANSLATION_QUALIFICATION_POSTFLIGHT=1"))
        #expect(script.contains("--filter HyMTQualificationPostflightTests"))
        #expect(script.contains("postflight_status=$?"))
        #expect(script.contains("SIDECAR_PATH=\"$REPORT_PATH.postflight.json\""))
        #expect(script.contains("[ -e \"$SIDECAR_PATH\" ] || [ -L \"$SIDECAR_PATH\" ]"))
        #expect(script.contains("if [ \"$postflight_status\" -ne 0 ]; then"))
        #expect(script.contains("postflight release-input verification failed"))
        #expect(script.contains("exit \"$qualification_status\""))
    }

    @Test func adjudicationCannotRunInferenceOrRewriteFrozenEvidence() throws {
        let files = [
            "HyMTQualificationAdjudicationTests.swift",
            "HyMTAdjudicationFrozenEvidence.swift",
            "HyMTAdjudicationFrozenEvidence+Loading.swift",
            "HyMTAdjudicationReviewEvidence.swift",
        ]
        let directory = workspaceRoot.appendingPathComponent("Tests/TranslationHyMT2Tests")
        let source = try files.map {
            try String(contentsOf: directory.appendingPathComponent($0), encoding: .utf8)
        }.joined(separator: "\n")

        #expect(source.contains("HyMTQualificationReportSnapshot.load"))
        #expect(source.contains("HyMTQualificationPostflightValidator.validate"))
        #expect(source.contains("TranslationQualificationFreezeVerifier.verify"))
        #expect(source.contains("decodeProductionReviewerRegistry"))
        #expect(source.contains("requireAttestedReleaseReadyGates"))
        #expect(!source.contains("loadModel"))
        #expect(!source.contains("HyMT2TranslationProvider"))
        #expect(!source.contains("TranslationQualificationReportBuilder"))
        #expect(!source.contains("TranslationQualificationReportWriter"))
        #expect(!source.contains("HyMTQualificationPostflightWriter"))
        #expect(!source.contains("Date()"))
    }

    @Test func onlyAttestedAdjudicationCanDeclareReleaseReady() throws {
        let qualification = try String(
            contentsOf: workspaceRoot.appendingPathComponent(
                "Tests/TranslationHyMT2Tests/HyMTBilingualSermonQualificationTests+Release.swift"
            ),
            encoding: .utf8
        )
        let adjudicationOutput = try String(
            contentsOf: workspaceRoot.appendingPathComponent(
                "Tests/TranslationHyMT2Tests/HyMTAdjudicationOutput.swift"
            ),
            encoding: .utf8
        )

        #expect(qualification.contains("AUTOMATED_QUALITY_GATES_READY="))
        #expect(!qualification.contains("RELEASE_READY="))
        #expect(adjudicationOutput.contains("RELEASE_READY=true"))
    }

    private func bootstrapFunction(in script: String) throws -> Substring {
        let start = try #require(script.range(of: "bootstrap() {"))
        let end = try #require(
            script.range(of: "\n}\n\nvalue_from", range: start.upperBound..<script.endIndex)
        )
        return script[start.lowerBound..<end.upperBound]
    }

    private var workspaceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
