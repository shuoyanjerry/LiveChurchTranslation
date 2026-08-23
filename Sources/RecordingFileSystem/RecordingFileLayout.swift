import Darwin
import Foundation

struct RecordingFileLayout {
    let root: URL
    let sessionID: UUID

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

    func prepareDirectories(fileManager: FileManager) throws {
        try createPrivateDirectory(root, fileManager: fileManager)
        try createPrivateDirectory(sessionDirectory, fileManager: fileManager)
    }

    func createPartial(header: Data, fileManager: FileManager) throws -> FileHandle {
        let descriptor = partialURL.path.withCString {
            Darwin.open($0, O_RDWR | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else { throw posixError("create partial recording") }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: header)
            try enforcePrivateFile(fileManager: fileManager)
            return handle
        } catch {
            try? handle.close()
            try? fileManager.removeItem(at: partialURL)
            throw error
        }
    }

    func createActiveMarker(fileManager: FileManager) throws {
        let descriptor = activeMarkerURL.path.withCString {
            Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else { throw posixError("create recording activity marker") }
        guard Darwin.close(descriptor) == 0 else {
            throw posixError("close recording activity marker")
        }
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: activeMarkerURL.path
        )
        try synchronizeDirectory()
    }

    func clearActiveMarker(fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: activeMarkerURL.path) else { return }
        try fileManager.removeItem(at: activeMarkerURL)
        try synchronizeDirectory()
    }

    func enforcePrivateFile(fileManager: FileManager) throws {
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: partialURL.path
        )
    }

    func publish() throws {
        let result = partialURL.path.withCString { source in
            finalURL.path.withCString { destination in
                renamex_np(source, destination, UInt32(RENAME_EXCL))
            }
        }
        guard result == 0 else { throw posixError("publish recording") }
    }

    func synchronizeDirectory() throws {
        let descriptor = sessionDirectory.path.withCString { Darwin.open($0, O_RDONLY) }
        guard descriptor >= 0 else { throw posixError("open session directory") }
        defer { Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw posixError("synchronize session directory")
        }
    }

    private func createPrivateDirectory(_ url: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o700)]
        )
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o700)],
            ofItemAtPath: url.path
        )
    }

    private func posixError(_ operation: String) -> NSError {
        let code = errno
        return NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(code),
            userInfo: [NSLocalizedDescriptionKey: "\(operation): \(String(cString: strerror(code)))"]
        )
    }
}
