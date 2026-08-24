import CryptoKit
import Foundation

public enum TranslationQualificationFreezeEvidence {
    public static func makeStatement(
        report: TranslationQualificationReport,
        artifacts: TranslationFreezeArtifactIdentity,
        frozenAt: String,
        requestID: String = UUID().uuidString
    ) throws -> TranslationQualificationFreezeStatement {
        guard let provenance = report.executionProvenance else { throw invalid }
        let statement = TranslationQualificationFreezeStatement(
            requestID: requestID,
            reportFilename: artifacts.reportFilename,
            postflightFilename: artifacts.postflightFilename,
            reviewPacketFilename: artifacts.reviewPacketFilename,
            reportFileSHA256: artifacts.reportSHA256,
            postflightFileSHA256: artifacts.postflightSHA256,
            reviewPacketSHA256: artifacts.reviewPacketSHA256,
            attemptContentsSHA256: try attemptContentsSHA256(report.attempts),
            reportBinding: try TranslationHumanReviewEvidence.reportBinding(for: report),
            executionProvenance: provenance,
            provider: report.provider,
            environment: report.environment,
            frozenAt: frozenAt
        )
        try validate(statement)
        return statement
    }

    public static func encodeStatement(
        _ statement: TranslationQualificationFreezeStatement
    ) throws -> Data {
        try validate(statement)
        return try canonicalData(statement)
    }

    public static func decodeStatement(
        from data: Data
    ) throws -> TranslationQualificationFreezeStatement {
        let statement: TranslationQualificationFreezeStatement = try decodeCanonical(data)
        try validate(statement)
        return statement
    }

    public static func encodeSignedFreeze(
        _ envelope: TranslationQualificationSignedFreeze
    ) throws -> Data {
        try canonicalData(envelope)
    }

    public static func signingPayload(
        statement: TranslationQualificationFreezeStatement,
        authorityKeyID: String
    ) throws -> Data {
        try validate(statement)
        return try canonicalData(
            SignedPayload(
                domain: "LIVE-CHURCH-TRANSLATION-HYMT-FREEZE-V1",
                schemaVersion: TranslationQualificationSignedFreeze.currentSchemaVersion,
                policyRevision: statement.policyRevision,
                authorityKeyID: authorityKeyID,
                statement: statement
            )
        )
    }

    public static func authorityKeyID(
        forPublicKeyBase64 value: String
    ) throws -> String {
        guard let data = canonicalBase64(value), data.count == 32 else { throw invalid }
        return "freeze-root-" + TranslationQualificationSHA256.hash(data: data)
    }

    public static func attemptContentsSHA256(
        _ attempts: [TranslationQualificationAttempt]
    ) throws -> String {
        var data = Data("LIVE-CHURCH-TRANSLATION-ATTEMPTS-V1\0".utf8)
        data.append(try canonicalData(attempts))
        return TranslationQualificationSHA256.hash(data: data)
    }
}

extension TranslationQualificationFreezeEvidence {
    static func decodeCanonical<T: Codable>(_ data: Data) throws -> T {
        try TranslationJSONDuplicateKeyValidator.validate(data)
        let value: T
        do {
            value = try JSONDecoder().decode(T.self, from: data)
        } catch let error as TranslationQualificationError {
            throw error
        } catch {
            throw invalid
        }
        guard try canonicalData(value) == data else { throw invalid }
        return value
    }

    static func validate(_ value: TranslationQualificationFreezeStatement) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampIsValid =
            ISO8601DateFormatter().date(from: value.frozenAt) != nil
            || formatter.date(from: value.frozenAt) != nil
        guard value.schemaVersion == TranslationQualificationFreezeStatement.currentSchemaVersion,
            value.policyRevision == TranslationQualificationFreezeStatement.currentPolicyRevision,
            UUID(uuidString: value.requestID)?.uuidString == value.requestID,
            validFilename(value.reportFilename),
            validFilename(value.postflightFilename),
            validFilename(value.reviewPacketFilename),
            value.postflightFilename == value.reportFilename + ".postflight.json",
            hashes(in: value).allSatisfy(TranslationProvenanceValidator.isSHA),
            TranslationProvenanceValidator.isStructurallyValid(value.executionProvenance),
            timestampIsValid
        else { throw invalid }
    }

    static var invalid: TranslationQualificationError {
        .invalidReport("signed qualification freeze evidence is invalid or untrusted")
    }

    private static func hashes(
        in value: TranslationQualificationFreezeStatement
    ) -> [String] {
        [
            value.reportFileSHA256, value.postflightFileSHA256,
            value.reviewPacketSHA256, value.attemptContentsSHA256,
            value.reportBinding.reportSHA256, value.reportBinding.manifestSHA256,
            value.reportBinding.attemptIdentitySHA256,
        ]
    }

    private static func validFilename(_ value: String) -> Bool {
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
        )
        return value.count <= 128 && value.hasSuffix(".json")
            && (value.first?.isLetter == true || value.first?.isNumber == true)
            && !value.contains("..") && value.unicodeScalars.allSatisfy(allowed.contains)
    }

    private static func canonicalBase64(_ value: String) -> Data? {
        guard let data = Data(base64Encoded: value), data.base64EncodedString() == value else {
            return nil
        }
        return data
    }

    private static func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        try TranslationHumanReviewEvidence.canonicalData(value)
    }

    private struct SignedPayload: Encodable {
        let domain: String
        let schemaVersion: Int
        let policyRevision: String
        let authorityKeyID: String
        let statement: TranslationQualificationFreezeStatement
    }
}
