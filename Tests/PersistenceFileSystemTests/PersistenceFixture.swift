import Foundation
import PersistenceFileSystem
import TranscriptAPI

struct PersistenceFixture {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let session = TranscriptSession(id: UUID(), startedAt: Date(), endedAt: nil, entries: [])
    let entry = TranscriptEntry(
        sequence: 1,
        sourceSegmentSequence: 3,
        rawSourceText: "嗯典",
        sourceText: "恩典",
        sourceCorrections: [
            TranscriptSourceCorrection(observedText: "嗯典", replacementText: "恩典")
        ],
        targetText: "grace",
        startedMilliseconds: 0,
        endedMilliseconds: 1_000,
        translationMilliseconds: 20
    )

    var store: FileTranscriptStore { FileTranscriptStore(root: root) }
    var sessionDirectory: URL { root.appending(path: session.id.uuidString) }
    var jsonLinesURL: URL { sessionDirectory.appending(path: "transcript.jsonl") }
    var markdownURL: URL { sessionDirectory.appending(path: "transcript.md") }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
