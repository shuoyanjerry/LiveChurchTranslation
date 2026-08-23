import Foundation
import RecordingAPI

enum PCM16CAF {
    static let headerByteCount: UInt64 = 68
    static let dataChunkSizeOffset: UInt64 = 56
    static let littleEndianIntegerFlags: UInt32 = 1 << 1

    static func header(
        format: RecordingFormat,
        dataByteCount: UInt64?
    ) -> Data {
        let bytesPerFrame = UInt32(format.channelCount * MemoryLayout<Int16>.size)
        var data = Data(capacity: Int(headerByteCount))
        data.appendASCII("caff")
        data.appendBigEndian(UInt16(1))
        data.appendBigEndian(UInt16(0))
        data.appendASCII("desc")
        data.appendBigEndian(UInt64(32))
        data.appendBigEndian(Double(format.sampleRate).bitPattern)
        data.appendASCII("lpcm")
        data.appendBigEndian(littleEndianIntegerFlags)
        data.appendBigEndian(bytesPerFrame)
        data.appendBigEndian(UInt32(1))
        data.appendBigEndian(UInt32(format.channelCount))
        data.appendBigEndian(UInt32(16))
        data.appendASCII("data")
        data.appendBigEndian(dataByteCount.map { $0 + 4 } ?? UInt64.max)
        data.appendBigEndian(UInt32(0))
        return data
    }

    static func readFormat(from header: Data) throws -> RecordingFormat {
        guard header.count == Int(headerByteCount) else {
            throw CAFHeaderError("header is not 68 bytes")
        }
        guard
            header.ascii(at: 0, count: 4) == "caff",
            header.uint16(at: 4) == 1,
            header.uint16(at: 6) == 0,
            header.ascii(at: 8, count: 4) == "desc",
            header.uint64(at: 12) == 32,
            header.ascii(at: 28, count: 4) == "lpcm",
            header.uint32(at: 32) == littleEndianIntegerFlags,
            header.uint32(at: 40) == 1,
            header.uint32(at: 48) == 16,
            header.ascii(at: 52, count: 4) == "data",
            header.uint32(at: 64) == 0
        else {
            throw CAFHeaderError("unsupported PCM16 CAF header")
        }
        let format = try recordingFormat(from: header)
        let expectedBytesPerFrame = UInt32(format.channelCount * MemoryLayout<Int16>.size)
        guard header.uint32(at: 36) == expectedBytesPerFrame else {
            throw CAFHeaderError("inconsistent PCM16 format fields")
        }
        return format
    }

    private static func recordingFormat(from header: Data) throws -> RecordingFormat {
        let sampleRateValue = Double(bitPattern: header.uint64(at: 20))
        let channelValue = header.uint32(at: 44)
        guard
            sampleRateValue.isFinite,
            sampleRateValue >= 1,
            sampleRateValue <= Double(UInt32.max),
            sampleRateValue.rounded(.towardZero) == sampleRateValue,
            let sampleRate = UInt32(exactly: sampleRateValue),
            channelValue > 0,
            channelValue <= UInt32.max / 2
        else {
            throw CAFHeaderError("invalid sample rate or channel count")
        }
        let channelCount = Int(channelValue)
        return RecordingFormat(sampleRate: sampleRate, channelCount: channelCount)
    }

    static func finalizeDataChunk(
        in handle: FileHandle,
        dataByteCount: UInt64
    ) throws {
        var size = Data(capacity: MemoryLayout<UInt64>.size)
        size.appendBigEndian(dataByteCount + 4)
        try handle.seek(toOffset: dataChunkSizeOffset)
        try handle.write(contentsOf: size)
    }
}

struct CAFHeaderError: Error, LocalizedError {
    let reason: String

    init(_ reason: String) {
        self.reason = reason
    }

    var errorDescription: String? { reason }
}

extension Data {
    fileprivate mutating func appendASCII(_ value: String) {
        append(contentsOf: value.utf8)
    }

    fileprivate mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }

    fileprivate func ascii(at offset: Int, count: Int) -> String {
        String(bytes: self[offset..<offset + count], encoding: .utf8) ?? ""
    }

    fileprivate func uint16(at offset: Int) -> UInt16 {
        (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }

    fileprivate func uint32(at offset: Int) -> UInt32 {
        (UInt32(self[offset]) << 24)
            | (UInt32(self[offset + 1]) << 16)
            | (UInt32(self[offset + 2]) << 8)
            | UInt32(self[offset + 3])
    }

    fileprivate func uint64(at offset: Int) -> UInt64 {
        (0..<8).reduce(into: UInt64(0)) { value, index in
            value = (value << 8) | UInt64(self[offset + index])
        }
    }
}
