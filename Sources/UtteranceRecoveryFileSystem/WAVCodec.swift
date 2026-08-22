import Foundation

enum WAVFormat {
    static let headerByteCount = 44
    static let bytesPerSample = 4
    static let formatCode: UInt16 = 3
}

struct DecodedWAV {
    let sampleRate: UInt32
    let samples: [Float]
}

enum WAVCodec {
    static func encode(samples: [Float], sampleRate: UInt32) -> Data {
        let payloadBytes = samples.count * WAVFormat.bytesPerSample
        var writer = LittleEndianWriter(capacity: WAVFormat.headerByteCount + payloadBytes)
        writer.appendASCII("RIFF")
        writer.append(UInt32(36 + payloadBytes))
        writer.appendASCII("WAVE")
        writer.appendASCII("fmt ")
        writer.append(UInt32(16))
        writer.append(WAVFormat.formatCode)
        writer.append(UInt16(1))
        writer.append(sampleRate)
        writer.append(sampleRate * UInt32(WAVFormat.bytesPerSample))
        writer.append(UInt16(WAVFormat.bytesPerSample))
        writer.append(UInt16(32))
        writer.appendASCII("data")
        writer.append(UInt32(payloadBytes))
        for sample in samples {
            writer.append(sample.bitPattern)
        }
        return writer.data
    }

    static func decode(_ data: Data) throws -> DecodedWAV {
        guard data.count >= WAVFormat.headerByteCount else { throw WAVReadError.malformed }
        let reader = LittleEndianReader(data: data)
        guard
            reader.ascii(at: 0, count: 4) == "RIFF",
            reader.uint32(at: 4) == UInt32(data.count - 8),
            reader.ascii(at: 8, count: 4) == "WAVE",
            reader.ascii(at: 12, count: 4) == "fmt ",
            reader.uint32(at: 16) == 16,
            reader.uint16(at: 20) == WAVFormat.formatCode,
            reader.uint16(at: 22) == 1,
            UInt64(reader.uint32(at: 28))
                == UInt64(reader.uint32(at: 24)) * UInt64(WAVFormat.bytesPerSample),
            reader.uint16(at: 32) == UInt16(WAVFormat.bytesPerSample),
            reader.uint16(at: 34) == 32,
            reader.ascii(at: 36, count: 4) == "data"
        else {
            throw WAVReadError.malformed
        }
        let payloadBytes = Int(reader.uint32(at: 40))
        guard
            payloadBytes.isMultiple(of: WAVFormat.bytesPerSample),
            WAVFormat.headerByteCount + payloadBytes == data.count
        else {
            throw WAVReadError.malformed
        }
        let samples = stride(from: WAVFormat.headerByteCount, to: data.count, by: 4).map {
            Float(bitPattern: reader.uint32(at: $0))
        }
        return DecodedWAV(sampleRate: reader.uint32(at: 24), samples: samples)
    }
}

enum WAVReadError: Error {
    case malformed
}
