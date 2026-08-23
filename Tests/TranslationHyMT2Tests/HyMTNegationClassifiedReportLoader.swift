import Foundation
@testable import TranslationQualificationSupport

struct HyMTNegationClassifiedEvidence: Sendable {
    let attempts: [TranslationQualificationAttempt]
    let reportSHA256: String

    var selectedSegmentIDs: Set<String> {
        Set(attempts.filter(HyMTNegationClassifiedReportLoader.isNegationFailure).map(\.segmentID))
    }
}

enum HyMTNegationClassifiedReportLoader {
    static func load(
        reportURL: URL,
        corpus: TranslationQualificationCorpus
    ) throws -> HyMTNegationClassifiedEvidence {
        let data = try boundedData(reportURL)
        let reportHash = TranslationQualificationSHA256.hash(data: data)
        guard reportHash == expectedReportSHA256 else {
            throw TranslationQualificationError.hashMismatch(
                label: "classified translation report",
                expected: expectedReportSHA256,
                actual: reportHash
            )
        }
        try TranslationJSONDuplicateKeyValidator.validate(data)
        let report: TranslationQualificationReport
        do {
            report = try JSONDecoder().decode(TranslationQualificationReport.self, from: data)
        } catch {
            throw TranslationQualificationError.invalidJSON(
                "classified translation report values are invalid"
            )
        }
        try validate(report, corpus: corpus)
        let selected = report.attempts.filter(isNegationFailure)
        guard !selected.isEmpty else {
            throw TranslationQualificationError.invalidReport(
                "classified report has no negation failures"
            )
        }
        return HyMTNegationClassifiedEvidence(
            attempts: report.attempts,
            reportSHA256: reportHash
        )
    }

    static func isNegationFailure(_ attempt: TranslationQualificationAttempt) -> Bool {
        guard attempt.status == .failure, let code = attempt.failureCode else { return false }
        return code.split(separator: ".").contains("neg")
    }

    private static func boundedData(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let bytes = values.fileSize, bytes <= maximumBytes else {
            throw TranslationQualificationError.invalidReport(
                "classified report is not a bounded regular file"
            )
        }
        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw TranslationQualificationError.missingFile("classified translation report")
        }
    }

    private static let maximumBytes = 16 * 1_024 * 1_024
    private static let expectedReportSHA256 =
        "7108b5bd53874da6446bb487a8c8d441c88bca1564214f77523418585cf51ff8"
}
