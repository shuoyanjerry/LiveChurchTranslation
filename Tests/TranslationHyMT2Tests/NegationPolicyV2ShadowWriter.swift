import Darwin
import Foundation
@testable import TranslationQualificationSupport

enum NegationPolicyV2ShadowWriter {
    static func write(
        _ report: NegationPolicyV2ShadowReport,
        sensitiveValues: [String],
        workspaceRoot: URL
    ) throws -> URL {
        let data = try NegationPolicyV2ShadowPrivacy.encoded(
            report,
            sensitiveValues: sensitiveValues
        )
        let url = try TranslationPrivateReportStorage(
            workspaceRoot: workspaceRoot,
            filename: NegationPolicyV2ShadowConfiguration.outputFilename
        ).write(data)
        let persisted = try Data(contentsOf: url)
        guard persisted == data else { throw NegationPolicyV2ShadowError.storageFailure }
        try NegationPolicyV2ShadowPrivacy.validateSerialized(
            persisted,
            sensitiveValues: sensitiveValues
        )
        let decoded = try JSONDecoder().decode(NegationPolicyV2ShadowReport.self, from: persisted)
        guard decoded == report else { throw NegationPolicyV2ShadowError.storageFailure }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.posixPermissions] as? NSNumber == NSNumber(value: 0o600) else {
            throw NegationPolicyV2ShadowError.storageFailure
        }
        return url
    }
}
