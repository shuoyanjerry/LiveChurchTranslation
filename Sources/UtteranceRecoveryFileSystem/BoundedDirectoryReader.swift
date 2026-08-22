import Foundation
import UtteranceRecoveryAPI

struct BoundedDirectoryReader {
    let fileManager: FileManager

    func rootEntries(at url: URL, maximum: Int) throws -> [URL] {
        try entries(at: url, maximum: maximum) {
            UtteranceRecoveryError.rootEntryCountExceeded(maximum: maximum)
        }
    }

    func sessionEntries(at url: URL, sessionID: UUID, maximum: Int) throws -> [URL] {
        try entries(at: url, maximum: maximum) {
            UtteranceRecoveryError.sessionEntryCountExceeded(
                sessionID: sessionID,
                maximum: maximum
            )
        }
    }

    private func entries(
        at url: URL,
        maximum: Int,
        limitError: () -> UtteranceRecoveryError
    ) throws -> [URL] {
        var enumerationError: Error?
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsSubdirectoryDescendants]
        ) { _, error in
            enumerationError = error
            return false
        }
        guard let enumerator else {
            throw CocoaError(.fileReadUnknown)
        }
        var result: [URL] = []
        for case let entry as URL in enumerator {
            guard result.count < maximum else { throw limitError() }
            result.append(entry)
        }
        if let enumerationError { throw enumerationError }
        return result
    }
}
