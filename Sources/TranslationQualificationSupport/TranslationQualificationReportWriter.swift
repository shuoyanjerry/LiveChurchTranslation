import Foundation

public enum TranslationQualificationReportWriter {
    public static func validatePrivateFilename(_ filename: String) throws {
        try TranslationPrivateReportStorage.validateFilename(filename)
    }

    @discardableResult
    public static func writePrivate(
        _ report: TranslationQualificationReport,
        releaseExpectation: TranslationReleaseExpectation,
        workspaceRoot: URL,
        filename: String
    ) throws -> URL {
        do {
            guard
                TranslationProvenanceValidator.isReleaseBound(
                    report,
                    expectation: releaseExpectation
                ),
                report.aggregate == TranslationQualificationReportBuilder.aggregate(report.attempts)
            else {
                throw TranslationQualificationError.invalidReport(
                    "private report does not match the trusted release expectation"
                )
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            return try TranslationPrivateReportStorage(
                workspaceRoot: workspaceRoot,
                filename: filename
            ).write(data)
        } catch let error as TranslationQualificationError {
            throw error
        } catch {
            throw TranslationQualificationError.writeFailed("private report write failed")
        }
    }
}
