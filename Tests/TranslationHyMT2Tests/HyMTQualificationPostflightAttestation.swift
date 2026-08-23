import Foundation
import TranslationQualificationSupport

struct HyMTQualificationPostflightAttestation: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let reportSHA256: String
    let sourceBundleSHA256: String
    let testExecutableSHA256: String
    let modelSHA256: String
    let helperSHA256: String
    let runtimeBundleSHA256: String
    let configurationSHA256: String
    let manifestSHA256: String
    let schemaSHA256: String
    let postflightTimestamp: String
    let postflightVerified: Bool

    init(
        reportSHA256: String,
        provenance: TranslationExecutionProvenance,
        postflightTimestamp: String
    ) throws {
        let hashes = [
            reportSHA256, provenance.sourceBundle.sha256,
            provenance.testExecutable.sha256, provenance.model.sha256,
            provenance.helper.sha256, provenance.runtimeBundle.sha256,
            provenance.configurationSHA256, provenance.manifestSHA256,
            provenance.corpusSchemaSHA256,
        ]
        guard hashes.allSatisfy(Self.isSHA256), Self.isISO8601(postflightTimestamp) else {
            throw TranslationQualificationError.invalidReport(
                "postflight attestation identity is invalid"
            )
        }
        schemaVersion = Self.currentSchemaVersion
        self.reportSHA256 = reportSHA256
        sourceBundleSHA256 = provenance.sourceBundle.sha256
        testExecutableSHA256 = provenance.testExecutable.sha256
        modelSHA256 = provenance.model.sha256
        helperSHA256 = provenance.helper.sha256
        runtimeBundleSHA256 = provenance.runtimeBundle.sha256
        configurationSHA256 = provenance.configurationSHA256
        manifestSHA256 = provenance.manifestSHA256
        schemaSHA256 = provenance.corpusSchemaSHA256
        self.postflightTimestamp = postflightTimestamp
        postflightVerified = true
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func isISO8601(_ value: String) -> Bool {
        if ISO8601DateFormatter().date(from: value) != nil { return true }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) != nil
    }
}
