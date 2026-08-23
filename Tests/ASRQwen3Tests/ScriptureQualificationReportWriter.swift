import Foundation

enum ScriptureQualificationReportWriter {
    @discardableResult
    static func write(
        _ report: ScriptureModelQualificationReport,
        to url: URL,
        workspaceRoot: URL
    ) throws -> URL {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(report)
            try ScriptureQualificationReportStorage(
                workspaceRoot: workspaceRoot,
                reportURL: url
            ).write(data)
            return url
        } catch {
            throw ScriptureModelQualificationError.reportWriteFailed
        }
    }
}
