import Darwin
import Foundation

struct DurableFileWriter {
    let fileManager: FileManager

    func createPrivateDirectory(_ url: URL) throws {
        let existed = fileManager.fileExists(atPath: url.path)
        if existed {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o700))],
            ofItemAtPath: url.path
        )
        try synchronizeDirectory(url)
        if !existed, url.deletingLastPathComponent() != url {
            try synchronizeDirectory(url.deletingLastPathComponent())
        }
    }

    func write(_ data: Data, to finalURL: URL) throws {
        let temporaryURL = finalURL.deletingLastPathComponent()
            .appending(path: ".tmp-\(UUID().uuidString.lowercased())")
        defer { try? fileManager.removeItem(at: temporaryURL) }
        try data.write(
            to: temporaryURL,
            options: [.withoutOverwriting, .completeFileProtectionUnlessOpen]
        )
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: temporaryURL.path
        )
        let handle = try FileHandle(forWritingTo: temporaryURL)
        defer { try? handle.close() }
        try handle.synchronize()
        try handle.close()
        try fileManager.moveItem(at: temporaryURL, to: finalURL)
        try synchronizeDirectory(finalURL.deletingLastPathComponent())
    }

    func synchronizeDirectory(_ url: URL) throws {
        let descriptor = open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }
}
