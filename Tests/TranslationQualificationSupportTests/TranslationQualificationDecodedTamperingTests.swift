import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationDecodedTamperingTests {
    @Test func trustedInputsRejectSelfConsistentDecodedTampering() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let original = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let expectation = try SyntheticTranslationReportFactory.releaseExpectation(
            corpus: corpus
        )
        let tamperedReports = try [
            tampered(original, mutate: changeHypothesis),
            tampered(original, mutate: changeTraceAndAggregate),
            tampered(original, mutate: changeProviderRevision),
            tampered(original, mutate: changeEnvironment),
            tampered(original, mutate: changeMetricPolicy),
        ]

        for report in tamperedReports {
            #expect(
                !TranslationQualificationReleaseGate.evaluate(
                    report,
                    expectation: expectation
                ).passesReleaseReadyGates
            )
            #expect(throws: TranslationQualificationError.self) {
                try TranslationQualificationReleaseGate.requireReleaseReadyGates(
                    report,
                    expectation: expectation
                )
            }
        }
        #expect(throws: TranslationQualificationError.self) {
            try TranslationQualificationReportWriter.writePrivate(
                tamperedReports[0],
                releaseExpectation: expectation,
                workspaceRoot: fixture.root,
                filename: "tampered-report.json"
            )
        }
    }
}

private func changeHypothesis(_ object: inout [String: Any]) throws {
    var attempts = try #require(object["attempts"] as? [[String: Any]])
    attempts[0]["hypothesisEnglish"] = "Fabricated but structurally valid output"
    object["attempts"] = attempts
}

private func changeTraceAndAggregate(_ object: inout [String: Any]) throws {
    var attempts = try #require(object["attempts"] as? [[String: Any]])
    var checks = try #require(attempts[0]["preservationChecks"] as? [[String: Any]])
    let traceIndex = checks.count - 1
    #expect(checks[traceIndex]["kind"] as? String == "pronounTraceIntegrity")
    #expect(checks[traceIndex]["status"] as? String == "pass")
    checks[traceIndex]["status"] = "fail"
    attempts[0]["preservationChecks"] = checks
    object["attempts"] = attempts

    var aggregate = try #require(object["aggregate"] as? [String: Any])
    let passes = try #require(aggregate["checkPassCount"] as? Int)
    let failures = try #require(aggregate["checkFailCount"] as? Int)
    aggregate["checkPassCount"] = passes - 1
    aggregate["checkFailCount"] = failures + 1
    object["aggregate"] = aggregate
}

private func changeProviderRevision(_ object: inout [String: Any]) throws {
    var provider = try #require(object["provider"] as? [String: Any])
    provider["modelRevision"] = "forged-revision"
    object["provider"] = provider
}

private func changeEnvironment(_ object: inout [String: Any]) throws {
    var environment = try #require(object["environment"] as? [String: Any])
    environment["backgroundLoad"] = "forged-background-load"
    object["environment"] = environment
}

private func changeMetricPolicy(_ object: inout [String: Any]) throws {
    object["metricPolicy"] = ["Everything passes by declaration."]
}

private func tampered(
    _ value: TranslationQualificationReport,
    mutate: (inout [String: Any]) throws -> Void
) throws -> TranslationQualificationReport {
    var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
    )
    try mutate(&object)
    return try JSONDecoder().decode(
        TranslationQualificationReport.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
}
