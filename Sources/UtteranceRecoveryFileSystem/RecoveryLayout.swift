import Foundation
import UtteranceRecoveryAPI

struct RecoveryLayout {
    let root: URL

    func sessionDirectory(_ sessionID: UUID) -> URL {
        root.appending(path: sessionID.uuidString.lowercased(), directoryHint: .isDirectory)
    }

    func pendingDirectory(_ sessionID: UUID) -> URL {
        sessionDirectory(sessionID).appending(path: "pending", directoryHint: .isDirectory)
    }

    func quarantineDirectory(_ sessionID: UUID) -> URL {
        sessionDirectory(sessionID).appending(path: "quarantine", directoryHint: .isDirectory)
    }

    var rootQuarantineDirectory: URL {
        root.appending(path: ".quarantine", directoryHint: .isDirectory)
    }

    func recordName(_ id: PendingUtteranceID) -> String {
        String(format: "%020llu-%@.utterance", id.sequenceNumber, id.segmentID.uuidString.lowercased())
    }

    func recordDirectory(_ id: PendingUtteranceID) -> URL {
        pendingDirectory(id.sessionID)
            .appending(path: recordName(id), directoryHint: .isDirectory)
    }

    func stagingDirectory(_ sessionID: UUID) -> URL {
        pendingDirectory(sessionID)
            .appending(path: ".staging-\(UUID().uuidString.lowercased())", directoryHint: .isDirectory)
    }

    func completionDirectory(_ sessionID: UUID) -> URL {
        pendingDirectory(sessionID)
            .appending(path: ".completed-\(UUID().uuidString.lowercased())", directoryHint: .isDirectory)
    }

    func metadataURL(in recordDirectory: URL) -> URL {
        recordDirectory.appending(path: "metadata.json")
    }

    func audioURL(in recordDirectory: URL) -> URL {
        recordDirectory.appending(path: "audio.wav")
    }
}
