import Foundation
import UtteranceRecoveryFileSystem
import VADAPI

struct RecoveryTestFixture {
    let root: URL
    let sessionID = UUID()
    let stagedAt = Date(timeIntervalSince1970: 1_777_000_000)

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func store(
        limits: UtteranceRecoveryLimits = .sermonDefault
    ) throws -> FileUtteranceRecoveryStore {
        try FileUtteranceRecoveryStore(root: root, limits: limits, now: { stagedAt })
    }

    func segment(
        sequence: UInt64 = 1,
        samples: [Float] = [0.25, -0.5, 0.75],
        sampleRate: Double = 16_000,
        startedAt: Duration = .milliseconds(125),
        endedAt: Duration = .milliseconds(875),
        reason: SpeechSegmentEndReason = .softSilence
    ) -> SpeechSegment {
        SpeechSegment(
            sequenceNumber: sequence,
            samples: samples,
            sampleRate: sampleRate,
            startedAt: startedAt,
            endedAt: endedAt,
            endReason: reason
        )
    }

    func pendingRecordDirectory() throws -> URL {
        let pending =
            root
            .appending(path: sessionID.uuidString.lowercased(), directoryHint: .isDirectory)
            .appending(path: "pending", directoryHint: .isDirectory)
        let contents = try FileManager.default.contentsOfDirectory(
            at: pending,
            includingPropertiesForKeys: nil
        )
        guard let record = contents.first(where: { $0.pathExtension == "utterance" }) else {
            throw RecoveryFixtureError.recordMissing
        }
        return record
    }

    func removeRoot() {
        try? FileManager.default.removeItem(at: root)
    }
}

enum RecoveryFixtureError: Error {
    case recordMissing
}
