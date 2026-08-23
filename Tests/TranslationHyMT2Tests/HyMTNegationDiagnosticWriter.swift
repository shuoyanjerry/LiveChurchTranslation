import Foundation
@testable import TranslationQualificationSupport

enum HyMTNegationDiagnosticWriter {
    static func writePrivate(
        _ report: HyMTNegationDiagnosticReport,
        sensitiveTexts: [String],
        workspaceRoot: URL,
        filename: String
    ) throws -> URL {
        let data = try HyMTNegationDiagnosticPrivacyGuard.encoded(
            report,
            sensitiveTexts: sensitiveTexts
        )
        return try TranslationPrivateReportStorage(
            workspaceRoot: workspaceRoot,
            filename: filename
        ).write(data)
    }
}
