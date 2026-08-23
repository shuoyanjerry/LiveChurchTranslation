import Foundation
import RecordingAPI
import RecordingFileSystem
import Testing

@Suite struct RecordingValidationTests {
    @Test func formatCannotChangeAfterFirstFrame() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)
        #expect(FileManager.default.fileExists(atPath: fixture.activeMarkerURL.path))
        try await store.append(fixture.frame(samples: [0, 0]), to: fixture.sessionID)

        await #expect(
            throws: RecordingStoreError.formatChanged(
                expected: RecordingFormat(sampleRate: 16_000, channelCount: 1),
                actual: RecordingFormat(sampleRate: 48_000, channelCount: 2)
            )
        ) {
            try await store.append(
                fixture.frame(samples: [0, 0], sampleRate: 48_000, channelCount: 2),
                to: fixture.sessionID
            )
        }
    }

    @Test func nonFiniteSamplesAreRejectedBeforeCreatingAFile() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)

        await #expect(throws: RecordingStoreError.nonFiniteSample(index: 1)) {
            try await store.append(
                fixture.frame(samples: [0, .nan, 0]),
                to: fixture.sessionID
            )
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.partialURL.path))

        try await store.append(fixture.frame(samples: [0.25]), to: fixture.sessionID)
        _ = try await store.finish(sessionID: fixture.sessionID)
        #expect(!FileManager.default.fileExists(atPath: fixture.activeMarkerURL.path))
    }

    @Test func cafCapacityExceedsEightHourStereoRequirement() throws {
        let eightHoursAt48KHzStereo = UInt64(48_000 * 2 * 2 * 8 * 60 * 60)
        #expect(RecordingFileLimits.cafMaximumDataBytes > UInt64(UInt32.max))
        #expect(RecordingFileLimits.cafMaximumDataBytes > eightHoursAt48KHzStereo)
        #expect(
            throws: RecordingStoreError.invalidConfiguration(
                "maximumDataBytes exceeds the CAF signed 64-bit file boundary"
            )
        ) {
            _ = try FileSessionRecordingStore(
                root: FileManager.default.temporaryDirectory,
                limits: RecordingFileLimits(maximumDataBytes: UInt64.max)
            )
        }
    }

    @Test func configuredDataBoundaryIsEnforced() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store(limits: RecordingFileLimits(maximumDataBytes: 4))
        try await store.begin(sessionID: fixture.sessionID)
        let stereoFrame = fixture.frame(samples: [0, 0], channelCount: 2)
        try await store.append(stereoFrame, to: fixture.sessionID)

        await #expect(
            throws: RecordingStoreError.dataLimitExceeded(
                attemptedBytes: 8,
                maximumBytes: 4
            )
        ) {
            try await store.append(stereoFrame, to: fixture.sessionID)
        }
        let metadata = try await store.finish(sessionID: fixture.sessionID)
        #expect(metadata.audioDataByteCount == 4)
    }
}

extension RecordingValidationTests {
    @Test func duplicateLifecycleOperationsFailDeterministically() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()

        await #expect(throws: RecordingStoreError.sessionNotActive(fixture.sessionID)) {
            try await store.append(fixture.frame(), to: fixture.sessionID)
        }
        try await store.begin(sessionID: fixture.sessionID)
        await #expect(throws: RecordingStoreError.sessionAlreadyActive(fixture.sessionID)) {
            try await store.begin(sessionID: fixture.sessionID)
        }
        await #expect(throws: RecordingStoreError.noAudio(fixture.sessionID)) {
            _ = try await store.finish(sessionID: fixture.sessionID)
        }
        await #expect(throws: RecordingStoreError.sessionNotActive(fixture.sessionID)) {
            try await store.append(fixture.frame(samples: [0]), to: fixture.sessionID)
        }
        try await store.begin(sessionID: fixture.sessionID)
        try await store.append(fixture.frame(samples: [0]), to: fixture.sessionID)
        _ = try await store.finish(sessionID: fixture.sessionID)
        await #expect(throws: RecordingStoreError.sessionNotActive(fixture.sessionID)) {
            _ = try await store.finish(sessionID: fixture.sessionID)
        }
        await #expect(throws: RecordingStoreError.recordingAlreadyExists(fixture.sessionID)) {
            try await store.begin(sessionID: fixture.sessionID)
        }
    }

    @Test func discardBeforeFirstFrameClearsActiveSession() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)

        try await store.discard(sessionID: fixture.sessionID)
        try await store.discard(sessionID: fixture.sessionID)

        await #expect(throws: RecordingStoreError.sessionNotActive(fixture.sessionID)) {
            _ = try await store.finish(sessionID: fixture.sessionID)
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.partialURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.activeMarkerURL.path))
        try await store.begin(sessionID: fixture.sessionID)
        try await store.discard(sessionID: fixture.sessionID)
    }

    @Test func discardAfterWritingDeletesOnlyUnpublishedAudio() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)
        try await store.append(fixture.frame(samples: [0.25]), to: fixture.sessionID)
        #expect(FileManager.default.fileExists(atPath: fixture.partialURL.path))

        try await store.discard(sessionID: fixture.sessionID)

        #expect(!FileManager.default.fileExists(atPath: fixture.partialURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.finalURL.path))
        #expect(try await store.repairInterruptedRecording(sessionID: fixture.sessionID) == nil)
    }

    @Test func discardNeverDeletesPublishedAudio() async throws {
        let fixture = RecordingTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        try await store.begin(sessionID: fixture.sessionID)
        try await store.append(fixture.frame(samples: [0.25]), to: fixture.sessionID)
        _ = try await store.finish(sessionID: fixture.sessionID)

        try await store.discard(sessionID: fixture.sessionID)

        #expect(FileManager.default.fileExists(atPath: fixture.finalURL.path))
    }
}
