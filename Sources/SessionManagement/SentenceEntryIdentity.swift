import CryptoKit
import Foundation

enum SentenceEntryIdentity {
    static func make(
        sourceSegmentID: UUID,
        ordinal: Int
    ) -> UUID {
        precondition(ordinal >= 0)
        guard ordinal > 0 else { return sourceSegmentID }
        var material = withUnsafeBytes(of: sourceSegmentID.uuid) { Data($0) }
        var encodedOrdinal = UInt64(ordinal).bigEndian
        withUnsafeBytes(of: &encodedOrdinal) { material.append(contentsOf: $0) }
        var bytes = Array(SHA256.hash(data: material).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return bytes.withUnsafeBufferPointer {
            UUID(
                uuid: (
                    $0[0], $0[1], $0[2], $0[3], $0[4], $0[5], $0[6], $0[7],
                    $0[8], $0[9], $0[10], $0[11], $0[12], $0[13], $0[14], $0[15]
                ))
        }
    }
}
