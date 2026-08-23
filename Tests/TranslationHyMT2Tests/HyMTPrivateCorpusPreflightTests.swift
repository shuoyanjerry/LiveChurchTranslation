import Foundation
import Testing
import TranslationQualificationSupport
@testable import TranslationHyMT2

@Suite("Hy-MT2 private corpus preflight")
struct HyMTPrivateCorpusPreflightTests {
    @Test(
        "verifies frozen corpus identity and every local source hash",
        .enabled(
            if: ProcessInfo.processInfo.environment["BILINGUAL_TRANSLATION_MANIFEST"] != nil,
            "Requires an explicit private bilingual manifest path."
        )
    )
    func verifiesPrivateCorpusWhenExplicitlyEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let manifestPath = environment["BILINGUAL_TRANSLATION_MANIFEST"] else { return }
        let workspace =
            environment["TRANSLATION_QUALIFICATION_WORKSPACE_ROOT"]
            ?? FileManager.default.currentDirectoryPath
        let corpus = try TranslationQualificationCorpusLoader.load(
            manifestURL: URL(fileURLWithPath: manifestPath),
            workspaceRoot: URL(fileURLWithPath: workspace, isDirectory: true),
            expectedManifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
            expectedSchemaSHA256: HyMTQualificationConfiguration.schemaSHA256
        )

        #expect(corpus.manifest.segments.count == 144)
        #expect(corpus.manifest.summary.taGlyphOccurrenceCount == 108)
        #expect(corpus.manifest.segments.filter { $0.featureTags.contains("taAmbiguity") }.count == 53)
        try HyMTQualificationGlossary.requireManifestCoverage(
            corpus.manifest.segments,
            limit: HyMT2Configuration().maximumGlossaryTerms
        )
    }
}
