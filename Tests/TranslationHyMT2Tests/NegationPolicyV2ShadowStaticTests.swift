import Darwin
import Foundation
import Testing

@Suite("Negation Policy V2 offline shadow static guards")
struct NegationPolicyV2ShadowStaticTests {
    @Test("disposition and associated-value counts reconcile")
    func aggregateCountsReconcile() throws {
        let aggregate = try NegationPolicyV2ShadowCounts.aggregate([
            .noFunctionalNegation,
            .requiresOvertCue(count: 1),
            .requiresOvertCue(count: 2),
            .humanReviewRequired(reason: .targetCueCountMismatch(expected: 2, observed: 1)),
            .humanReviewRequired(reason: .unsafeTargetUnicode),
        ])

        #expect(aggregate.totalCount == 5)
        #expect(aggregate.dispositions.noFunctionalNegation == 1)
        #expect(aggregate.dispositions.requiresOvertCue == 2)
        #expect(aggregate.dispositions.humanReviewRequired == 2)
        #expect(aggregate.overtCueRequirements.one == 1)
        #expect(aggregate.overtCueRequirements.two == 1)
        #expect(aggregate.humanReviewReasons.targetCueCountMismatch == 1)
        #expect(aggregate.humanReviewReasons.unsafeTargetUnicode == 1)
    }

    @Test("configuration hash is deterministic and fixed inputs are pinned")
    func configurationIdentityIsStable() throws {
        let first = try NegationPolicyV2ShadowIdentity.configurationSHA256()
        let second = try NegationPolicyV2ShadowIdentity.configurationSHA256()

        #expect(first == second)
        #expect(first.count == 64)
        #expect(NegationPolicyV2ShadowIdentity.classifiedReportSHA256.hasSuffix("ff8"))
    }

    @Test("privacy encoding contains only allowlisted aggregate metadata")
    func aggregateEncodingRejectsPrivateFieldsAndValues() throws {
        let protected = "Private spiritual corpus sentence."
        let data = try NegationPolicyV2ShadowPrivacy.encoded(
            NegationPolicyV2ShadowTestFixture.report(),
            sensitiveValues: [protected]
        )
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(!text.contains(protected))
        #expect(!text.contains("segmentID"))
        #expect(!text.contains("hypothesisEnglish"))
        #expect(throws: NegationPolicyV2ShadowError.self) {
            try NegationPolicyV2ShadowPrivacy.validateSerialized(
                Data(#"{"segmentID":"Private spiritual corpus sentence."}"#.utf8),
                sensitiveValues: [protected]
            )
        }
    }

    @Test("writer is atomic-private storage with mode 0600")
    func writerUsesFixedPrivateArtifact() throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let url = try NegationPolicyV2ShadowWriter.write(
            NegationPolicyV2ShadowTestFixture.report(),
            sensitiveValues: ["Private spiritual corpus sentence."],
            workspaceRoot: workspace
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

        #expect(url.lastPathComponent == NegationPolicyV2ShadowConfiguration.outputFilename)
        #expect(attributes[.posixPermissions] as? NSNumber == NSNumber(value: 0o600))
    }

    @Test("invalid opt-in never silently enables private input reads")
    func configurationRequiresExactOptIn() throws {
        #expect(try NegationPolicyV2ShadowConfiguration.load([:]) == nil)
        #expect(throws: NegationPolicyV2ShadowError.self) {
            _ = try NegationPolicyV2ShadowConfiguration.load([
                NegationPolicyV2ShadowConfiguration.optInKey: "true"
            ])
        }
    }
}
