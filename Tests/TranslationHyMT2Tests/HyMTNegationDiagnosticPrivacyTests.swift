import Darwin
import Foundation
import Testing
import TranslationQualificationSupport

@Suite("Hy-MT2 negation diagnostic privacy")
struct HyMTNegationDiagnosticPrivacyTests {
    @Test func encodedReportContainsOnlyDiagnosticMetadata() throws {
        let report = HyMTNegationDiagnosticTestFixture.report(entries: [entry()])
        let protected = ["Private original sentence.", "Private reference sentence."]
        let data = try HyMTNegationDiagnosticPrivacyGuard.encoded(
            report,
            sensitiveTexts: protected
        )
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(protected.allSatisfy { !text.contains($0) })
        #expect(!text.contains("hypothesisEnglish"))
        #expect(!text.contains("contextSegmentIDs"))
    }

    @Test func serializedGuardRejectsForbiddenFieldsAndProtectedValues() {
        let forbiddenFields = [
            "originalChinese", "observedASRText", "referenceEnglish",
            "hypothesisEnglish", "contextSegmentIDs", "translationSourceText",
        ]
        for field in forbiddenFields {
            #expect(throws: TranslationQualificationError.self) {
                try HyMTNegationDiagnosticPrivacyGuard.validateSerialized(
                    Data("{\"\(field)\":\"private\"}".utf8),
                    sensitiveTexts: ["private"]
                )
            }
        }
        let leaked = Data(#"{"segmentID":"Private sermon sentence"}"#.utf8)
        #expect(throws: TranslationQualificationError.self) {
            try HyMTNegationDiagnosticPrivacyGuard.validateSerialized(
                leaked,
                sensitiveTexts: ["Private sermon sentence"]
            )
        }
    }

    @Test func writerUsesPrivateArtifactDirectoryAndMode() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let url = try HyMTNegationDiagnosticWriter.writePrivate(
            HyMTNegationDiagnosticTestFixture.report(entries: [entry()]),
            sensitiveTexts: ["Private sermon sentence."],
            workspaceRoot: workspace,
            filename: "negation-diagnostic.json"
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect(attributes[.posixPermissions] as? NSNumber == NSNumber(value: 0o600))
        #expect(url.path.contains("/.artifacts/translation-qualification/"))
    }

    private func entry() -> HyMTNegationDiagnosticEntry {
        HyMTNegationDiagnosticEntry(
            segmentID: "synthetic-segment", sourceID: "synthetic-source", sequence: 1,
            classifiedFailureCode: "hymt.strict.neg", sourceCueClasses: [.compoundBu],
            referenceCueClass: .lexical, attemptCount: 1, totalLatencySeconds: 0.01,
            terminalFailureCode: "hymt.strict.neg",
            attempts: [
                HyMTNegationDiagnosticAttempt(
                    ordinal: 1, phase: .initial,
                    completionOutcome: "initial.validationRejected", targetCueClass: .lexical,
                    validationIssueCodes: [.missingNegation], latencySeconds: 0.01,
                    outputAvailable: true, outputSHA256: String(repeating: "d", count: 64)
                )
            ]
        )
    }

    private func temporaryWorkspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
