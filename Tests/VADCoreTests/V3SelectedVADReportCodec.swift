import Foundation

enum V3SelectedVADReportCodec {
    static func encode(
        _ report: V3SelectedVADReport,
        forbiddenValues: [String]
    ) throws -> Data {
        try V3SelectedVADReportValidator.validate(report)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        let decoded = try JSONDecoder().decode(V3SelectedVADReport.self, from: data)
        guard try encoder.encode(decoded) == data else {
            throw V3SelectedVADError.provenanceMismatch("canonical report")
        }
        try validatePrivacy(data, forbiddenValues: forbiddenValues)
        return data
    }

    static func validatePrivacy(_ data: Data, forbiddenValues: [String]) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw V3SelectedVADError.privacyFailure
        }
        let lowered = text.lowercased()
        let forbiddenFields = [
            "itemid", "relativewavpath", "sourcepath", "filename",
            "transcript", "referencetext", "title", "speaker", "audiourl",
        ]
        guard !forbiddenFields.contains(where: lowered.contains) else {
            throw V3SelectedVADError.privacyFailure
        }
        for value in Set(forbiddenValues) where value.count >= 4 {
            guard !text.contains(value) else { throw V3SelectedVADError.privacyFailure }
        }
    }
}
