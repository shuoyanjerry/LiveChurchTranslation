import Foundation

enum CandidatePauseReportEncoder {
    static func encode(
        _ document: CandidatePauseBenchmarkDocument,
        forbiddenValues: [String]
    ) throws -> Data {
        try CandidatePauseDocumentValidator.validate(document)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        try CandidatePausePrivacyValidator.validate(
            encoded: data,
            forbiddenValues: forbiddenValues
        )
        let decoded = try JSONDecoder().decode(CandidatePauseCanonicalDocument.self, from: data)
        guard decoded.schemaVersion == 2, decoded.mode == "shadowOnly",
            decoded.decisionAuthority == "none"
        else { throw CandidatePauseBenchmarkError.invalidTrace("canonical round trip failed") }
        return data
    }
}

private struct CandidatePauseCanonicalDocument: Decodable {
    let schemaVersion: Int
    let mode: String
    let decisionAuthority: String
}
