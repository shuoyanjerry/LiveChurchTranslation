import Foundation
import TranslationQualificationSupport

enum HyMTQualificationPostflightValidator {
    static func validate(
        snapshot: HyMTQualificationReportSnapshot,
        corpus: TranslationQualificationCorpus,
        provenance: TranslationExecutionProvenance,
        configuration: HyMTQualificationConfiguration,
        timestamp: String
    ) throws -> HyMTQualificationPostflightAttestation {
        guard TranslationQualificationSHA256.hash(data: snapshot.data) == snapshot.sha256 else {
            throw invalid("postflight report digest does not match its snapshot")
        }
        let report = try decode(snapshot.data)
        guard report.schemaVersion == 2, report.executionProvenance == provenance else {
            throw invalid("postflight report is not bound to current execution provenance")
        }
        let provider = HyMTQualificationPostflightIdentity.provider(
            configuration: configuration,
            provenance: provenance
        )
        let environment = HyMTQualificationPostflightIdentity.environment(
            configuration: configuration
        )
        let rebuilt = try rebuild(
            report,
            corpus: corpus,
            provider: provider,
            environment: environment,
            provenance: provenance
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard try encoder.encode(rebuilt) == snapshot.data else {
            throw invalid("postflight report encoding is not canonical")
        }
        return try HyMTQualificationPostflightAttestation(
            reportSHA256: snapshot.sha256,
            provenance: provenance,
            postflightTimestamp: timestamp
        )
    }

    private static func decode(_ data: Data) throws -> TranslationQualificationReport {
        do {
            return try JSONDecoder().decode(TranslationQualificationReport.self, from: data)
        } catch {
            throw invalid("postflight report cannot be decoded")
        }
    }

    private static func rebuild(
        _ report: TranslationQualificationReport,
        corpus: TranslationQualificationCorpus,
        provider: TranslationQualificationProvider,
        environment: TranslationQualificationEnvironment,
        provenance: TranslationExecutionProvenance
    ) throws -> TranslationQualificationReport {
        guard report.provider == provider, report.environment == environment else {
            throw invalid("postflight report metadata is not current trusted metadata")
        }
        let rebuilt = try TranslationQualificationReportBuilder.build(
            generatedAt: report.generatedAt,
            corpus: corpus,
            provider: provider,
            environment: environment,
            executionProvenance: provenance,
            attempts: report.attempts
        )
        guard rebuilt == report else {
            throw invalid("postflight report does not reproduce from the frozen corpus")
        }
        return rebuilt
    }

    private static func invalid(_ message: String) -> TranslationQualificationError {
        .invalidReport(message)
    }
}
