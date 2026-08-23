import DiscourseResolutionCore
import Foundation
import Testing
import TranslationQualificationSupport

@Suite("Discourse resolver private bilingual qualification")
struct DiscourseBilingualQualificationTests {
    @Test(
        "replays frozen turns with two persisted turns per source",
        .enabled(
            if: DiscourseQualificationConfiguration.isRequested(
                ProcessInfo.processInfo.environment
            ),
            "Requires the frozen private corpus and an explicit report filename."
        )
    )
    func qualifyWhenExplicitlyEnabled() throws {
        guard
            let configuration = try DiscourseQualificationConfiguration.load(
                ProcessInfo.processInfo.environment
            )
        else { return }
        let corpus = try TranslationQualificationCorpusLoader.load(
            manifestURL: configuration.manifestURL,
            workspaceRoot: configuration.workspaceRoot,
            expectedManifestSHA256: DiscourseQualificationConfiguration.manifestSHA256,
            expectedSchemaSHA256: DiscourseQualificationConfiguration.schemaSHA256
        )
        let segments = try DiscourseQualificationRunner(
            resolver: DiscourseResolver()
        ).run(corpus)
        let report = DiscourseQualificationReportBuilder.build(
            corpus: corpus,
            segments: segments
        )
        try DiscourseQualificationReportValidator.validate(report, corpus: corpus)
        let reportURL = try DiscourseQualificationReportWriter(
            workspaceRoot: configuration.workspaceRoot,
            filename: configuration.reportFilename
        ).write(report, corpus: corpus)
        let reportSHA256 = try TranslationQualificationSHA256.hash(fileAt: reportURL)
        print("DISCOURSE_QUALIFICATION_REPORT_SHA256=\(reportSHA256)")
        try DiscourseQualificationGate.requireNoHardFailures(report)
    }
}
