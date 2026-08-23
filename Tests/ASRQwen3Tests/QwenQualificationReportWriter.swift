import ASRQualificationSupport
import Foundation

enum QwenQualificationReportWriter {
    static func encode(_ report: ASRQualificationReportV3) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    static func write(_ report: ASRQualificationReportV3, to url: URL) throws {
        try encode(report).write(to: url, options: .atomic)
    }
}
