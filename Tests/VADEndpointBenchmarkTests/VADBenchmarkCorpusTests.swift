import Foundation
import Testing

@Suite struct VADBenchmarkCorpusTests {
    @Test func fingerprintFollowsSymlinkAndDetectsReplacement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("source.wav")
        let link = directory.appendingPathComponent("linked.wav")
        try Data("abc".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: target
        )

        let original = try VADBenchmarkCorpus.fingerprint(link)
        #expect(original.byteCount == 3)
        #expect(
            original.sha256
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )

        try Data("replacement".utf8).write(to: target, options: .atomic)
        let replaced = try VADBenchmarkCorpus.fingerprint(link)
        #expect(replaced != original)
        #expect(replaced.byteCount == 11)
    }
}
