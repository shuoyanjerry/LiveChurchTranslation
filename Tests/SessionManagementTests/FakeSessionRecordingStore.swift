import AudioCaptureAPI
import Foundation
import RecordingAPI

actor FakeSessionRecordingStore: SessionRecordingStore {
    private let failAppendAfterWrite: Bool
    private let failFinish: Bool
    private let failRepair: Bool
    private var active: Set<UUID> = []
    private var frames: [UUID: [AudioFrame]] = [:]
    private var completed: Set<UUID> = []
    private var discarded: Set<UUID> = []
    private var repaired: Set<UUID> = []

    init(
        failAppendAfterWrite: Bool = false,
        failFinish: Bool = false,
        failRepair: Bool = false
    ) {
        self.failAppendAfterWrite = failAppendAfterWrite
        self.failFinish = failFinish
        self.failRepair = failRepair
    }

    func begin(sessionID: UUID) throws {
        active.insert(sessionID)
    }

    func append(_ frame: AudioFrame, to sessionID: UUID) throws {
        guard active.contains(sessionID) else {
            throw RecordingStoreError.sessionNotActive(sessionID)
        }
        frames[sessionID, default: []].append(frame)
        if failAppendAfterWrite {
            active.remove(sessionID)
            throw RecordingStoreError.fileSystem(
                operation: "append",
                reason: "Injected write interruption"
            )
        }
    }

    func finish(sessionID: UUID) throws -> SessionRecordingMetadata {
        guard active.remove(sessionID) != nil else {
            throw RecordingStoreError.sessionNotActive(sessionID)
        }
        if failFinish {
            throw RecordingStoreError.fileSystem(
                operation: "finish",
                reason: "Injected finalization interruption"
            )
        }
        guard let values = frames[sessionID], let first = values.first else {
            throw RecordingStoreError.noAudio(sessionID)
        }
        completed.insert(sessionID)
        let frameCount = values.reduce(0) { $0 + $1.frameCount }
        let format = RecordingFormat(
            sampleRate: UInt32(first.sampleRate),
            channelCount: first.channelCount
        )
        return SessionRecordingMetadata(
            sessionID: sessionID,
            fileURL: FileManager.default.temporaryDirectory.appending(path: "recording.caf"),
            format: format,
            frameCount: UInt64(frameCount),
            audioDataByteCount: UInt64(frameCount * first.channelCount * 2),
            recoveredFromInterruption: false
        )
    }

    func discard(sessionID: UUID) {
        active.remove(sessionID)
        frames.removeValue(forKey: sessionID)
        discarded.insert(sessionID)
    }

    func repairInterruptedRecording(sessionID: UUID) throws -> SessionRecordingMetadata? {
        if failRepair {
            throw RecordingStoreError.fileSystem(
                operation: "repair",
                reason: "Injected recovery interruption"
            )
        }
        guard let values = frames[sessionID], let first = values.first else { return nil }
        repaired.insert(sessionID)
        let frameCount = values.reduce(0) { $0 + $1.frameCount }
        return SessionRecordingMetadata(
            sessionID: sessionID,
            fileURL: FileManager.default.temporaryDirectory.appending(path: "recording.caf"),
            format: RecordingFormat(
                sampleRate: UInt32(first.sampleRate),
                channelCount: first.channelCount
            ),
            frameCount: UInt64(frameCount),
            audioDataByteCount: UInt64(frameCount * first.channelCount * 2),
            recoveredFromInterruption: true
        )
    }

    func recordedFrames() -> [AudioFrame] { frames.values.flatMap { $0 } }
    func completedSessionCount() -> Int { completed.count }
    func discardedSessionCount() -> Int { discarded.count }
    func repairedSessionCount() -> Int { repaired.count }
}
