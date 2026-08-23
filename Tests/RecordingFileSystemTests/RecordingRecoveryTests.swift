import Foundation
import RecordingAPI
import RecordingFileSystem
import Testing

@Suite struct RecordingRecoveryTests {
    @Test func interruptedPartialIsTrimmedRepairedAndPublished() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        var interruptedStore: FileSessionRecordingStore? = try fixture.store()
        try await interruptedStore?.begin(sessionID: fixture.sessionID)
        try await interruptedStore?.append(
            fixture.frame(samples: [0.25, -0.25], sampleRate: 48_000, channelCount: 2),
            to: fixture.sessionID
        )
        interruptedStore = nil

        let stale = try Data(contentsOf: fixture.partialURL)
        #expect(stale.testBigUInt64(at: 56) == UInt64.max)
        let tailWriter = try FileHandle(forWritingTo: fixture.partialURL)
        try tailWriter.seekToEnd()
        try tailWriter.write(contentsOf: Data([0x7f]))
        try tailWriter.close()

        let recoveryStore = try fixture.store()
        let recovered = try #require(
            try await recoveryStore.repairInterruptedRecording(sessionID: fixture.sessionID)
        )
        let caf = try Data(contentsOf: fixture.finalURL)

        #expect(recovered.recoveredFromInterruption)
        #expect(recovered.frameCount == 1)
        #expect(recovered.audioDataByteCount == 4)
        #expect(caf.count == 72)
        #expect(caf.testBigUInt64(at: 56) == 8)
        #expect(!FileManager.default.fileExists(atPath: fixture.partialURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.activeMarkerURL.path))
        #expect(
            try await recoveryStore.repairInterruptedRecording(
                sessionID: fixture.sessionID
            ) == nil)
    }

    @Test func publishedFinalWithStaleMarkerIsValidatedAndRecovered() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)
        try await store.append(fixture.frame(samples: [0.25]), to: fixture.sessionID)
        let original = try await store.finish(sessionID: fixture.sessionID)
        try Data().write(to: fixture.activeMarkerURL, options: .withoutOverwriting)

        let restarted = try fixture.store()
        let recovered = try #require(
            try await restarted.repairInterruptedRecording(sessionID: fixture.sessionID)
        )

        #expect(recovered.recoveredFromInterruption)
        #expect(recovered.frameCount == original.frameCount)
        #expect(recovered.audioDataByteCount == original.audioDataByteCount)
        #expect(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.activeMarkerURL.path))
    }

    @Test func activeRecordingCannotBeRepaired() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)

        await #expect(throws: RecordingStoreError.sessionAlreadyActive(fixture.sessionID)) {
            _ = try await store.repairInterruptedRecording(sessionID: fixture.sessionID)
        }
    }

    @Test func crashBeforeFirstFrameClearsOrphanActivityMarker() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        var interruptedStore: FileSessionRecordingStore? = try fixture.store()
        try await interruptedStore?.begin(sessionID: fixture.sessionID)
        #expect(FileManager.default.fileExists(atPath: fixture.activeMarkerURL.path))
        interruptedStore = nil

        let recoveryStore = try fixture.store()
        #expect(
            try await recoveryStore.repairInterruptedRecording(sessionID: fixture.sessionID) == nil
        )
        #expect(!FileManager.default.fileExists(atPath: fixture.activeMarkerURL.path))
    }

    @Test func malformedPartialReportsAStableError() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        try FileManager.default.createDirectory(
            at: fixture.sessionDirectory,
            withIntermediateDirectories: true
        )
        try Data(repeating: 0, count: 68).write(to: fixture.partialURL)
        let store = try fixture.store()

        await #expect(
            throws: RecordingStoreError.malformedPartialRecording(
                sessionID: fixture.sessionID,
                reason: "unsupported PCM16 CAF header"
            )
        ) {
            _ = try await store.repairInterruptedRecording(sessionID: fixture.sessionID)
        }
    }
}
