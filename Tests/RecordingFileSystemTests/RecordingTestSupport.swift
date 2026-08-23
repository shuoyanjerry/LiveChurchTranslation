import AudioCaptureAPI
import Foundation
import RecordingFileSystem

struct RecordingTestFixture {
    let root: URL
    let sessionID = UUID()

    init() {
        root = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
    }

    func store(
        limits: RecordingFileLimits = RecordingFileLimits()
    ) throws -> FileSessionRecordingStore {
        try FileSessionRecordingStore(root: root, limits: limits)
    }

    func frame(
        samples: [Float] = [0, 1, -1],
        sampleRate: Double = 16_000,
        channelCount: Int = 1
    ) -> AudioFrame {
        AudioFrame(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: channelCount,
            timestamp: .zero
        )
    }

    var sessionDirectory: URL {
        root.appending(
            path: sessionID.uuidString,
            directoryHint: .isDirectory
        )
    }

    var partialURL: URL {
        sessionDirectory.appending(path: "recording.partial.caf")
    }

    var finalURL: URL {
        sessionDirectory.appending(path: "recording.caf")
    }

    var activeMarkerURL: URL {
        sessionDirectory.appending(path: ".recording-active")
    }

    func removeRoot() {
        try? FileManager.default.removeItem(at: root)
    }
}

extension Data {
    func testASCII(at offset: Int, count: Int) -> String {
        String(bytes: self[offset..<offset + count], encoding: .utf8) ?? ""
    }

    func testLittleUInt16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func testLittleInt16(at offset: Int) -> Int16 {
        Int16(bitPattern: testLittleUInt16(at: offset))
    }

    func testBigUInt16(at offset: Int) -> UInt16 {
        (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }

    func testBigUInt32(at offset: Int) -> UInt32 {
        (UInt32(self[offset]) << 24)
            | (UInt32(self[offset + 1]) << 16)
            | (UInt32(self[offset + 2]) << 8)
            | UInt32(self[offset + 3])
    }

    func testBigUInt64(at offset: Int) -> UInt64 {
        (0..<8).reduce(into: UInt64(0)) { value, index in
            value = (value << 8) | UInt64(self[offset + index])
        }
    }
}
