import AVFAudio
import Foundation
import Testing

@Suite struct RecordingCAFTests {
    @Test func monoRecordingHasCanonicalPCM16HeaderAndSamples() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)
        try await store.append(fixture.frame(), to: fixture.sessionID)

        let metadata = try await store.finish(sessionID: fixture.sessionID)
        let caf = try Data(contentsOf: metadata.fileURL)
        let audioFile = try AVAudioFile(forReading: metadata.fileURL)

        #expect(caf.count == 74)
        #expect(caf.testASCII(at: 0, count: 4) == "caff")
        #expect(caf.testBigUInt16(at: 4) == 1)
        #expect(caf.testBigUInt16(at: 6) == 0)
        #expect(caf.testASCII(at: 8, count: 4) == "desc")
        #expect(caf.testBigUInt64(at: 12) == 32)
        #expect(Double(bitPattern: caf.testBigUInt64(at: 20)) == 16_000)
        #expect(caf.testASCII(at: 28, count: 4) == "lpcm")
        #expect(caf.testBigUInt32(at: 32) == 2)
        #expect(caf.testBigUInt32(at: 36) == 2)
        #expect(caf.testBigUInt32(at: 40) == 1)
        #expect(caf.testBigUInt32(at: 44) == 1)
        #expect(caf.testBigUInt32(at: 48) == 16)
        #expect(caf.testASCII(at: 52, count: 4) == "data")
        #expect(caf.testBigUInt64(at: 56) == 10)
        #expect(caf.testBigUInt32(at: 64) == 0)
        #expect(caf.testLittleInt16(at: 68) == 0)
        #expect(caf.testLittleInt16(at: 70) == Int16.max)
        #expect(caf.testLittleInt16(at: 72) == Int16.min)
        #expect(audioFile.length == 3)
        #expect(metadata.frameCount == 3)
        #expect(metadata.audioDataByteCount == 6)
        #expect(metadata.durationSeconds == 3.0 / 16_000.0)
        #expect(!metadata.recoveredFromInterruption)
    }

    @Test func stereoSamplesStayInterleaved() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)
        try await store.append(
            fixture.frame(
                samples: [1, -1, 0.5, -0.5],
                sampleRate: 48_000,
                channelCount: 2
            ),
            to: fixture.sessionID
        )

        let metadata = try await store.finish(sessionID: fixture.sessionID)
        let caf = try Data(contentsOf: metadata.fileURL)

        #expect(caf.testBigUInt32(at: 36) == 4)
        #expect(caf.testBigUInt32(at: 44) == 2)
        #expect(caf.testBigUInt64(at: 56) == 12)
        #expect(caf.testLittleInt16(at: 68) == Int16.max)
        #expect(caf.testLittleInt16(at: 70) == Int16.min)
        #expect(caf.testLittleInt16(at: 72) == 16_384)
        #expect(caf.testLittleInt16(at: 74) == -16_384)
        #expect(metadata.frameCount == 2)
        #expect(metadata.format.channelCount == 2)
    }

    @Test func recordingArtifactsUsePrivatePermissions() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)
        try await store.append(fixture.frame(), to: fixture.sessionID)
        _ = try await store.finish(sessionID: fixture.sessionID)

        let manager = FileManager.default
        let rootMode = try manager.attributesOfItem(atPath: fixture.root.path)[.posixPermissions]
        let sessionMode = try manager.attributesOfItem(
            atPath: fixture.sessionDirectory.path
        )[.posixPermissions]
        let fileMode = try manager.attributesOfItem(atPath: fixture.finalURL.path)[.posixPermissions]

        #expect((rootMode as? NSNumber)?.intValue == 0o700)
        #expect((sessionMode as? NSNumber)?.intValue == 0o700)
        #expect((fileMode as? NSNumber)?.intValue == 0o600)
    }
}
