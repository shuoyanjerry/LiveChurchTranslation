import Foundation

enum TranslationAttemptIdentityDigest {
    static func hash(_ segments: [TranslationQualificationSegment]) -> String {
        hash(
            segments.map {
                Identity(segmentID: $0.id, sourceID: $0.sourceID, sequence: $0.sequence)
            }
        )
    }

    static func hash(_ attempts: [TranslationQualificationAttempt]) -> String {
        hash(
            attempts.map {
                Identity(
                    segmentID: $0.segmentID,
                    sourceID: $0.sourceID,
                    sequence: $0.sequence
                )
            }
        )
    }

    private static func hash(_ identities: [Identity]) -> String {
        var data = Data("TRANSLATION-ATTEMPT-IDENTITIES-V1\0".utf8)
        append(UInt64(identities.count), to: &data)
        for identity in identities {
            append(Data(identity.segmentID.utf8), to: &data)
            append(Data(identity.sourceID.utf8), to: &data)
            append(Data(String(identity.sequence).utf8), to: &data)
        }
        return TranslationQualificationSHA256.hash(data: data)
    }

    private static func append(_ value: Data, to output: inout Data) {
        append(UInt64(value.count), to: &output)
        output.append(value)
    }

    private static func append(_ value: UInt64, to output: inout Data) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { output.append(contentsOf: $0) }
    }

    private struct Identity {
        let segmentID: String
        let sourceID: String
        let sequence: Int
    }
}
