import Foundation
import TranslationQualificationSupport

extension NegationPolicyV2OfflineShadowTests {
    func execute(_ configuration: NegationPolicyV2ShadowConfiguration) throws {
        let corpus = try loadCorpus(configuration)
        let classified = try HyMTNegationClassifiedReportLoader.load(
            reportURL: configuration.classifiedReportURL,
            corpus: corpus
        )
        let report = try NegationPolicyV2ShadowBuilder.make(
            corpus: corpus,
            classified: classified,
            workspaceRoot: configuration.workspaceRoot
        )
        let url = try NegationPolicyV2ShadowWriter.write(
            report,
            sensitiveValues: NegationPolicyV2ShadowSensitiveValues.collect(
                corpus: corpus,
                classified: classified
            ),
            workspaceRoot: configuration.workspaceRoot
        )
        let reportSHA256 = try TranslationQualificationSHA256.hash(fileAt: url)
        printSummary(report, reportSHA256: reportSHA256)
    }

    private func loadCorpus(
        _ configuration: NegationPolicyV2ShadowConfiguration
    ) throws -> TranslationQualificationCorpus {
        try TranslationQualificationCorpusLoader.load(
            manifestURL: configuration.manifestURL,
            workspaceRoot: configuration.workspaceRoot,
            expectedManifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
            expectedSchemaSHA256: HyMTQualificationConfiguration.schemaSHA256
        )
    }

    private func printSummary(
        _ report: NegationPolicyV2ShadowReport,
        reportSHA256: String
    ) {
        print("NEGATION_POLICY_V2_SHADOW_REPORT_SHA256=\(reportSHA256)")
        print("NEGATION_POLICY_V2_SHADOW_POLICY_SHA256=\(report.policySHA256)")
        print("NEGATION_POLICY_V2_SHADOW_CONFIGURATION_SHA256=\(report.configurationSHA256)")
        print("NEGATION_POLICY_V2_SHADOW_TOTAL=\(report.totalSegmentCount)")
        print("NEGATION_POLICY_V2_SHADOW_SUCCESS=\(report.classifiedSuccessCount)")
        print("NEGATION_POLICY_V2_SHADOW_FAILURE=\(report.classifiedFailureCount)")
        print(
            "NEGATION_POLICY_V2_SHADOW_ACCEPTED_UNSAFE_TARGET_UNICODE="
                + "\(report.acceptedUnsafeTargetUnicodeCount)"
        )
    }
}
