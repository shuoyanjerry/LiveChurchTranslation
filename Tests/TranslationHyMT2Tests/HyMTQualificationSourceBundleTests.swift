import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HyMTQualificationSourceBundleTests {
    @Test func isDeterministicAndBindsAddedOrChangedFiles() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try HyMTQualificationSourceBundle.capture(workspaceRoot: root)
        let second = try HyMTQualificationSourceBundle.capture(workspaceRoot: root)
        #expect(first == second)

        let source = root.appendingPathComponent("Sources/Feature.swift")
        try Data("let value = 2\n".utf8).write(to: source)
        let changed = try HyMTQualificationSourceBundle.capture(workspaceRoot: root)
        #expect(changed.sha256 != first.sha256)
        #expect(changed.entryCount == first.entryCount)

        try Data("test\n".utf8).write(
            to: root.appendingPathComponent("Tests/NewEvidence.swift")
        )
        let added = try HyMTQualificationSourceBundle.capture(workspaceRoot: root)
        #expect(added.sha256 != changed.sha256)
        #expect(added.entryCount == changed.entryCount + 1)
    }

    @Test func excludesBuildArtifactsAndRejectsSourceSymlinks() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let baseline = try HyMTQualificationSourceBundle.capture(workspaceRoot: root)
        let ignored = root.appendingPathComponent("Sources/.build", isDirectory: true)
        try FileManager.default.createDirectory(at: ignored, withIntermediateDirectories: true)
        try Data("ignored\n".utf8).write(to: ignored.appendingPathComponent("output"))
        #expect(try HyMTQualificationSourceBundle.capture(workspaceRoot: root) == baseline)

        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("Scripts/unsafe.swift"),
            withDestinationURL: root.appendingPathComponent("Package.swift")
        )
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTQualificationSourceBundle.capture(workspaceRoot: root)
        }
    }

    private func workspace() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        for directory in ["Sources", "Tests", "Scripts"] {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(directory),
                withIntermediateDirectories: true
            )
        }
        try Data("// package\n".utf8).write(to: root.appendingPathComponent("Package.swift"))
        try Data("{}\n".utf8).write(to: root.appendingPathComponent("Package.resolved"))
        try Data("let value = 1\n".utf8).write(
            to: root.appendingPathComponent("Sources/Feature.swift")
        )
        try Data("test\n".utf8).write(to: root.appendingPathComponent("Tests/Test.swift"))
        try Data("#!/bin/bash\n".utf8).write(to: root.appendingPathComponent("Scripts/run.sh"))
        return root
    }
}
