import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationReleaseExpectationTests {
    @Test func decodedReportAloneIsDiagnosticOnly() throws {
        let values = try releaseValues()
        let decoded = try JSONDecoder().decode(
            TranslationQualificationReport.self,
            from: JSONEncoder().encode(values.report)
        )

        #expect(!TranslationQualificationReleaseGate.evaluate(decoded).passesReleaseReadyGates)
        #expect(
            TranslationQualificationReleaseGate.evaluate(decoded).provenanceBindingFailureCount == 1
        )
    }

    @Test func forgedEmptyAttemptReportCannotReleaseOrBeWritten() throws {
        let values = try releaseValues()
        let forged = try report(values.report) { object in
            object["attempts"] = []
            object["aggregate"] = emptyReleaseAggregate()
        }

        #expect(
            !TranslationQualificationReleaseGate.evaluate(
                forged,
                expectation: values.expectation
            ).passesReleaseReadyGates
        )
        #expect(throws: TranslationQualificationError.self) {
            try TranslationQualificationReportWriter.writePrivate(
                forged,
                releaseExpectation: values.expectation,
                workspaceRoot: values.workspace.root,
                filename: "forged-empty.json"
            )
        }
    }

    @Test func wrongExpectedDigestCountAndIdentityFailClosed() throws {
        let values = try releaseValues()
        let expectations = try wrongExpectations(values.expectation)

        for (index, expectation) in expectations.enumerated() {
            #expect(
                !TranslationQualificationReleaseGate.evaluate(
                    values.report,
                    expectation: expectation
                ).passesReleaseReadyGates
            )
            #expect(throws: TranslationQualificationError.self) {
                try TranslationQualificationReportWriter.writePrivate(
                    values.report,
                    releaseExpectation: expectation,
                    workspaceRoot: values.workspace.root,
                    filename: "wrong-expectation-\(index).json"
                )
            }
        }
    }

    @Test func changedAttemptIdentityFailsCorrectExternalExpectation() throws {
        let values = try releaseValues()
        let forged = try report(values.report) { object in
            var attempts = try #require(object["attempts"] as? [[String: Any]])
            attempts[0]["segmentID"] = "forged-segment"
            object["attempts"] = attempts
        }

        #expect(
            !TranslationQualificationReleaseGate.evaluate(
                forged,
                expectation: values.expectation
            ).passesReleaseReadyGates
        )
    }

    @Test func correctExternalExpectationPassesReleaseReadyGate() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let result = TranslationQualificationReleaseGate.evaluate(
            values.report,
            expectation: values.expectation
        )

        #expect(result.passesReleaseReadyGates)
        try TranslationQualificationReleaseGate.requireReleaseReadyGates(
            values.report,
            expectation: values.expectation
        )
    }
}
