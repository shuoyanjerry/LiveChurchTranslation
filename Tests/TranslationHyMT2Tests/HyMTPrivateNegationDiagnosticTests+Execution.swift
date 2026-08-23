import Foundation
import TranslationQualificationSupport
@testable import TranslationHyMT2

extension HyMTPrivateNegationDiagnosticTests {
    func validatedInputs(
        _ configuration: HyMTNegationDiagnosticConfiguration
    ) throws -> HyMTPrivateNegationInputs {
        do {
            _ = try HyMTQualificationRuntimeVerifier.verify(
                configuration.qualificationConfiguration
            )
            let corpus = try TranslationQualificationCorpusLoader.load(
                manifestURL: configuration.manifestURL,
                workspaceRoot: configuration.workspaceRoot,
                expectedManifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
                expectedSchemaSHA256: HyMTQualificationConfiguration.schemaSHA256
            )
            let classified = try HyMTNegationClassifiedReportLoader.load(
                reportURL: configuration.classifiedReportURL,
                corpus: corpus
            )
            return HyMTPrivateNegationInputs(corpus: corpus, classified: classified)
        } catch {
            throw HyMTPrivateNegationDiagnosticError.inputValidationFailed
        }
    }

    func start(
        _ provider: HyMT2TranslationProvider,
        modelURL: URL
    ) async throws {
        do {
            try await provider.loadModel(at: modelURL)
        } catch {
            await provider.shutdown()
            throw HyMTPrivateNegationDiagnosticError.modelStartupFailed
        }
    }

    func replay(
        _ runner: HyMTNegationDiagnosticRunner,
        provider: HyMT2TranslationProvider,
        corpus: TranslationQualificationCorpus,
        classified: HyMTNegationClassifiedEvidence
    ) async throws -> HyMTNegationDiagnosticRunResult {
        do {
            return try await runner.run(corpus: corpus, classified: classified)
        } catch {
            await provider.shutdown()
            throw HyMTPrivateNegationDiagnosticError.replayFailed
        }
    }

    func store(
        _ result: HyMTNegationDiagnosticRunResult,
        configuration: HyMTNegationDiagnosticConfiguration,
        corpus: TranslationQualificationCorpus,
        classified: HyMTNegationClassifiedEvidence,
        provider: HyMT2TranslationProvider
    ) async throws -> URL {
        do {
            let url = try HyMTNegationDiagnosticWriter.writePrivate(
                result.report,
                sensitiveTexts: sensitiveTexts(corpus: corpus, classified: classified)
                    + result.protectedModelOutputs,
                workspaceRoot: configuration.workspaceRoot,
                filename: configuration.reportFilename
            )
            await provider.shutdown()
            return url
        } catch {
            await provider.shutdown()
            throw HyMTPrivateNegationDiagnosticError.privacyOrStorageFailed
        }
    }

    func sensitiveTexts(
        corpus: TranslationQualificationCorpus,
        classified: HyMTNegationClassifiedEvidence
    ) -> [String] {
        let corpusTexts = corpus.manifest.segments.flatMap {
            [$0.originalChinese, $0.observedASRAmbiguousChinese, $0.referenceEnglish]
        }
        let reportTexts = classified.attempts.flatMap {
            [$0.translationSourceText, $0.hypothesisEnglish ?? ""]
        }
        return corpusTexts + reportTexts
    }
}

private enum HyMTPrivateNegationDiagnosticError: Error {
    case inputValidationFailed
    case modelStartupFailed
    case replayFailed
    case privacyOrStorageFailed
}

struct HyMTPrivateNegationInputs: Sendable {
    let corpus: TranslationQualificationCorpus
    let classified: HyMTNegationClassifiedEvidence
}
