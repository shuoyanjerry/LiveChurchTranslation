import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HyMTQualificationReviewEvidenceTests {
    @Test func strictRegistryRequiresRootSignedCanonicalReviewers() throws {
        let evidence = try signedRegistry()
        let registry = evidence.registry
        let data = try TranslationHumanReviewEvidence.encodeReviewerRegistry(registry)
        #expect(
            try TranslationHumanReviewEvidence.verifyReviewerRegistry(
                from: data,
                trustPolicy: evidence.policy
            ) == registry
        )
        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationHumanReviewEvidence.decodeProductionReviewerRegistry(from: data)
        }

        let text = try #require(String(data: data, encoding: .utf8))
        let duplicate = Data(
            text.replacingOccurrences(
                of: "{",
                with: "{\"policyRevision\":\"translation-human-review-v1\",",
                options: [],
                range: text.startIndex..<text.index(after: text.startIndex)
            ).utf8
        )
        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationHumanReviewEvidence.decodeUntrustedReviewerRegistry(from: duplicate)
        }
    }

    @Test func packetBindsFileAndCanonicalHashesAndContainsBlindReviewContent() throws {
        let values = try semanticReport()
        let packet = try TranslationHumanReviewEvidence.makeReviewPacket(
            report: values.report,
            expectation: values.expectation,
            reportFileSHA256: sha("7"),
            postflightFileSHA256: sha("8")
        )

        #expect(packet.reportFileSHA256 == sha("7"))
        #expect(packet.postflightFileSHA256 == sha("8"))
        #expect(packet.reportBinding.reportSHA256 != packet.reportFileSHA256)
        #expect(packet.items.count >= 5)
        #expect(semanticAxes.isSubset(of: Set(packet.items.map(\.reviewSubject))))
        #expect(packet.items.allSatisfy { $0.sourceText == "合成标题" })
        #expect(packet.items.allSatisfy { $0.targetText == "Synthetic title" })
        #expect(packet.items.allSatisfy { $0.referenceText == "Synthetic reference" })
        #expect(packet.items.allSatisfy { $0.itemID.count == 64 && $0.humanResolvable })
        let packetData = try TranslationHumanReviewEvidence.encodeReviewPacket(packet)
        #expect(try TranslationHumanReviewEvidence.decodeReviewPacket(from: packetData) == packet)

        let workspace = try HyMTPostflightTestFixture.temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let url = try TranslationHumanReviewEvidence.writePrivateReviewPacket(
            packet,
            workspaceRoot: workspace,
            filename: "synthetic-review-packet.json"
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(throws: TranslationQualificationError.self) {
            try TranslationHumanReviewEvidence.writePrivateReviewPacket(
                packet,
                workspaceRoot: workspace,
                filename: "synthetic-review-packet.json"
            )
        }
    }

    @Test func privateInputRejectsPermissionDriftAndSymlink() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hymt-review-input-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("registry.json")
        let data = Data("{\"fixed\":true}".utf8)
        try data.write(to: input, options: .withoutOverwriting)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: input.path
        )
        let digest = TranslationQualificationSHA256.hash(data: data)
        #expect(try HyMTQualificationPrivateFile.read(at: input, expectedSHA256: digest) == data)

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o644)],
            ofItemAtPath: input.path
        )
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTQualificationPrivateFile.read(at: input, expectedSHA256: digest)
        }
        let link = root.appendingPathComponent("registry-link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: input)
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTQualificationPrivateFile.read(at: link, expectedSHA256: digest)
        }
    }
}
