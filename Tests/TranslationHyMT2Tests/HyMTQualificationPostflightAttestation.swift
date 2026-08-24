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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StrictKey.self)
        let expected = Set([
            "schemaVersion", "reportSHA256", "sourceBundleSHA256",
            "testExecutableSHA256", "modelSHA256", "helperSHA256",
            "runtimeBundleSHA256", "configurationSHA256", "manifestSHA256",
            "schemaSHA256", "postflightTimestamp", "postflightVerified",
        ])
        guard Set(container.allKeys.map(\.stringValue)) == expected else {
            throw TranslationQualificationError.invalidReport(
                "postflight attestation has missing or unknown fields"
            )
        }
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        reportSHA256 = try values.decode(String.self, forKey: .reportSHA256)
        sourceBundleSHA256 = try values.decode(String.self, forKey: .sourceBundleSHA256)
        testExecutableSHA256 = try values.decode(String.self, forKey: .testExecutableSHA256)
        modelSHA256 = try values.decode(String.self, forKey: .modelSHA256)
        helperSHA256 = try values.decode(String.self, forKey: .helperSHA256)
        runtimeBundleSHA256 = try values.decode(String.self, forKey: .runtimeBundleSHA256)
        configurationSHA256 = try values.decode(String.self, forKey: .configurationSHA256)
        manifestSHA256 = try values.decode(String.self, forKey: .manifestSHA256)
        schemaSHA256 = try values.decode(String.self, forKey: .schemaSHA256)
        postflightTimestamp = try values.decode(String.self, forKey: .postflightTimestamp)
        postflightVerified = try values.decode(Bool.self, forKey: .postflightVerified)
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

private struct StrictKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
