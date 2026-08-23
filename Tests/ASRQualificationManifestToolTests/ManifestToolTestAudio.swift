import CryptoKit
import Foundation

enum ManifestToolTestAudio {
    static let samples: [Float] = [0.25, -0.5, 0.75, 0]

    static func wav() -> Data {
        var audio = Data()
        for sample in samples {
            audio.appendLittleEndian(sample.bitPattern)
        }
        var format = Data()
        format.appendLittleEndian(UInt16(3))
        format.appendLittleEndian(UInt16(1))
        format.appendLittleEndian(UInt32(16_000))
        format.appendLittleEndian(UInt32(64_000))
        format.appendLittleEndian(UInt16(4))
        format.appendLittleEndian(UInt16(32))
        return riff(format: format, audio: audio)
    }

    static func pcmSHA256() -> String {
        var data = Data()
        for sample in samples {
            data.appendLittleEndian(sample.bitPattern)
        }
        return sha256(data)
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func riff(format: Data, audio: Data) -> Data {
        var body = Data("WAVE".utf8)
        body.appendChunk(id: "fmt ", payload: format)
        body.appendChunk(id: "data", payload: audio)
        var result = Data("RIFF".utf8)
        result.appendLittleEndian(UInt32(body.count))
        result.append(body)
        return result
    }
}

extension Data {
    fileprivate mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var encoded = value.littleEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }

    fileprivate mutating func appendChunk(id: String, payload: Data) {
        append(Data(id.utf8))
        appendLittleEndian(UInt32(payload.count))
        append(payload)
        if !payload.count.isMultiple(of: 2) { append(0) }
    }
}
