import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    func append(_ data: Data, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    func writeEntries(_ entries: [TranscriptEntry], sessionID: UUID) throws {
        let encoder = lineEncoder()
        var payload = Data()
        for entry in entries {
            payload.append(try encoder.encode(entry))
            payload.append(0x0A)
        }
        try payload.write(to: jsonLinesURL(sessionID), options: .atomic)
        entryIDs[sessionID] = Set(entries.map(\.id))
    }

    func markdownHeader(for session: TranscriptSession) -> String {
        "# Live Church Translation\n\n开始时间：\(session.startedAt.formatted())\n\n"
    }

    func markdown(for entry: TranscriptEntry) -> String {
        "## \(entry.sequence)\n\n\(entry.targetText)\n\n> \(entry.sourceText)\n\n"
    }

    func completeMarkdown(
        for session: TranscriptSession,
        finalization: TranscriptFinalization
    ) -> String {
        markdownHeader(for: session)
            + session.entries.map(markdown).joined()
            + "\n---\n\(finalization.markdownNotice)\n"
    }

    func loadEntryIDsIfNeeded(sessionID: UUID) throws -> Set<UUID> {
        if let loaded = entryIDs[sessionID] { return loaded }
        let identifiers = Set(try readEntries(sessionID: sessionID).map(\.id))
        entryIDs[sessionID] = identifiers
        return identifiers
    }

    func readEntries(sessionID: UUID) throws -> [TranscriptEntry] {
        let data = try Data(contentsOf: jsonLinesURL(sessionID))
        let decoder = lineDecoder()
        return try data.split(separator: 0x0A).map {
            try decoder.decode(TranscriptEntry.self, from: Data($0))
        }
    }

    func sessionDirectory(_ id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    func manifestURL(_ id: UUID) -> URL {
        sessionDirectory(id).appending(path: "session.json")
    }

    func jsonLinesURL(_ id: UUID) -> URL {
        sessionDirectory(id).appending(path: "transcript.jsonl")
    }

    func markdownURL(_ id: UUID) -> URL {
        sessionDirectory(id).appending(path: "transcript.md")
    }

    func lineEncoder() -> JSONEncoder { configuredEncoder() }
    func lineDecoder() -> JSONDecoder { decoder() }

    func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func configuredEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension TranscriptFinalization {
    fileprivate var markdownNotice: String {
        switch integrity {
        case .complete:
            "会议记录完整。"
        case .incomplete:
            "会议记录未完整处理，请结合完整录音核对。"
        case .recoveredAfterInterruption:
            "会议记录已在意外中断后恢复，内容可能不完整，请结合录音核对。"
        case .active:
            "会议记录仍在处理中。"
        }
    }
}
