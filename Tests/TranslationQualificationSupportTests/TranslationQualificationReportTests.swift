import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationQualificationReportTests {
    @Test func includesEverySuccessAndFailureInAggregate() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let report = try SyntheticTranslationReportFactory.build(
            corpus: fixture.load(),
            failingIndex: 10
        )

        #expect(report.aggregate.attemptCount == 100)
        #expect(report.aggregate.successCount == 99)
        #expect(report.aggregate.failureCount == 1)
        #expect(report.attempts[10].failureCode == "synthetic.transport-failure")
        #expect(report.metricPolicy.contains { $0.contains("No BLEU") })
    }

    @Test func rejectsContextNotDerivedFromLastTwoSuccesses() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()

        #expect(throws: TranslationQualificationError.self) {
            _ = try SyntheticTranslationReportFactory.build(
                corpus: corpus,
                invalidContextIndex: 2
            )
        }
    }

    @Test func writesPrivateReportAtomically() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)

        let output = try TranslationQualificationReportWriter.writePrivate(
            report,
            releaseExpectation: try SyntheticTranslationReportFactory.releaseExpectation(
                corpus: corpus
            ),
            workspaceRoot: fixture.root,
            filename: "synthetic-report.json"
        )
        let decoded = try JSONDecoder().decode(
            TranslationQualificationReport.self,
            from: Data(contentsOf: output)
        )
        #expect(decoded.aggregate.attemptCount == 100)
        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        #expect(attributes[.posixPermissions] as? Int == 0o600)
    }

    @Test func refusesToOverwriteExistingEvidence() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let expectation = try SyntheticTranslationReportFactory.releaseExpectation(corpus: corpus)
        let output = try TranslationQualificationReportWriter.writePrivate(
            report,
            releaseExpectation: expectation,
            workspaceRoot: fixture.root,
            filename: "immutable-report.json"
        )
        let original = try Data(contentsOf: output)

        #expect(throws: TranslationQualificationError.self) {
            try TranslationQualificationReportWriter.writePrivate(
                report,
                releaseExpectation: expectation,
                workspaceRoot: fixture.root,
                filename: "immutable-report.json"
            )
        }
        #expect(try Data(contentsOf: output) == original)
    }

    @Test func legacyV1IsDiagnosticOnlyAndCannotBePersistedOrReleased() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(
            corpus: corpus,
            includeExecutionProvenance: false
        )
        let decoded = try JSONDecoder().decode(
            TranslationQualificationReport.self,
            from: JSONEncoder().encode(report)
        )

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.executionProvenance == nil)
        #expect(!TranslationQualificationReleaseGate.evaluate(decoded).passesReleaseReadyGates)
        #expect(throws: TranslationQualificationError.self) {
            try TranslationQualificationReportWriter.writePrivate(
                decoded,
                releaseExpectation: try SyntheticTranslationReportFactory.releaseExpectation(
                    corpus: corpus
                ),
                workspaceRoot: fixture.root,
                filename: "legacy-report.json"
            )
        }
    }
}

extension TranslationQualificationReportTests {
    @Test func tamperedAggregateCannotPassReleaseReadyGate() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let data = try JSONEncoder().encode(report)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var aggregate = try #require(object["aggregate"] as? [String: Any])
        aggregate["attemptCount"] = 1
        object["aggregate"] = aggregate
        let tampered = try JSONDecoder().decode(
            TranslationQualificationReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        let expectation = try SyntheticTranslationReportFactory.releaseExpectation(corpus: corpus)
        #expect(
            !TranslationQualificationReleaseGate.evaluate(
                tampered,
                expectation: expectation
            ).passesReleaseReadyGates
        )
    }

    @Test func rejectsUnsafePrivateReportFilenames() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let expectation = try SyntheticTranslationReportFactory.releaseExpectation(corpus: corpus)

        for filename in ["../report.json", "/tmp/report.json", ".hidden.json", "report.txt"] {
            #expect(throws: TranslationQualificationError.self) {
                try TranslationQualificationReportWriter.writePrivate(
                    report,
                    releaseExpectation: expectation,
                    workspaceRoot: fixture.root,
                    filename: filename
                )
            }
        }
    }
}
