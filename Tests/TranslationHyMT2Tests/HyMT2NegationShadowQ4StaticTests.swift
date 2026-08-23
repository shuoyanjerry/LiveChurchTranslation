import Foundation
import Testing

@Suite("Hy-MT2 public negation-marker Q4 static gates")
struct HyMT2NegationShadowQ4StaticTests {
    @Test("covers both encodings at zero, one, two, and three occurrences")
    func coversMatrixCardinalities() throws {
        #expect(HyMT2NegationShadowQ4Fixtures.all.count == 11)
        for encoding in HyMT2NegationShadowEncoding.allCases {
            var counts: [Int: Int] = [:]
            for (index, fixture) in HyMT2NegationShadowQ4Fixtures.all.enumerated() {
                let plan = try fixture.plan(encoding: encoding, index: index)
                counts[plan.occurrences.count, default: 0] += 1
                #expect(
                    fixture.occurrenceAnchorAlternatives.count == plan.occurrences.count,
                    "Anchor mismatch in public fixture \(fixture.identifier)"
                )
            }
            #expect(counts == [0: 4, 1: 5, 2: 1, 3: 1])
        }
    }

    @Test("accepts an obviously aligned public clause")
    func acceptsObviousSemanticAttribution() throws {
        let fixture = try #require(
            HyMT2NegationShadowQ4Fixtures.all.first { $0.identifier == "one.not" }
        )
        let plan = try fixture.plan(encoding: .originalCue, index: 0)
        let marker = try #require(plan.occurrences.first).protectedBlock
        let output = "The church does not\(marker) hide the truth."
        let parsed = try HyMT2NegationMarkerShadowParser.parse(output, plan: plan)

        #expect(throws: Never.self) {
            try HyMT2NegationShadowSemanticOracle.validate(
                rawOutput: output,
                parsed: parsed,
                plan: plan,
                fixture: fixture
            )
        }
    }

    @Test("rejects structurally valid markers swapped across obvious clauses")
    func rejectsSwappedSemanticAttribution() throws {
        let fixture = try #require(
            HyMT2NegationShadowQ4Fixtures.all.first { $0.identifier == "two.no.never" }
        )
        let plan = try fixture.plan(encoding: .englishNot, index: 4)
        let first = plan.occurrences[0].protectedBlock
        let second = plan.occurrences[1].protectedBlock
        let output = "God never\(first) forgets the promise; no\(second) one is justified by works."
        let parsed = try HyMT2NegationMarkerShadowParser.parse(output, plan: plan)

        #expect(throws: HyMT2NegationShadowSemanticFailure.anchorMissing) {
            try HyMT2NegationShadowSemanticOracle.validate(
                rawOutput: output,
                parsed: parsed,
                plan: plan,
                fixture: fixture
            )
        }
    }

    @Test("serializes only approved report fields")
    func reportSchemaDoesNotCarryText() throws {
        let report = HyMT2NegationShadowQ4Report(
            environment: sampleEnvironment,
            results: [sampleResult]
        )
        let data = try HyMT2NegationShadowQ4ReportWriter.encoded(report)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let result = try #require((root["results"] as? [[String: Any]])?.first)

        #expect(Set(root.keys) == approvedRootKeys)
        #expect(Set(result.keys) == approvedResultKeys)
        let serialized = try #require(String(data: data, encoding: .utf8)).lowercased()
        for forbidden in ["prompt", "rawoutput", "sourcetext", "targettext", "cleantarget"] {
            #expect(!serialized.contains(forbidden))
        }
    }

    @Test("pins decoding and artifact identities")
    func pinsRunIdentity() {
        #expect(HyMT2NegationShadowQ4Settings.seed == 42)
        #expect(HyMT2NegationShadowQ4Settings.temperature == 0)
        #expect(HyMT2NegationShadowQ4Settings.threadCount == 4)
        #expect(HyMT2NegationShadowQ4Settings.expectedModelSHA256.count == 64)
        #expect(HyMT2NegationShadowQ4Settings.expectedHelperSHA256.count == 64)
    }

    private var sampleEnvironment: HyMT2NegationShadowQ4Environment {
        HyMT2NegationShadowQ4Environment(
            modelURL: URL(fileURLWithPath: "/public/model.gguf"),
            helperURL: URL(fileURLWithPath: "/public/helper"),
            reportURL: URL(fileURLWithPath: "/public/report.json"),
            modelSHA256: HyMT2NegationShadowQ4Settings.expectedModelSHA256,
            helperSHA256: HyMT2NegationShadowQ4Settings.expectedHelperSHA256
        )
    }

    private var sampleResult: HyMT2NegationShadowQ4Result {
        HyMT2NegationShadowQ4Result(
            fixtureID: "one.not",
            encoding: "englishNot",
            occurrenceCount: 1,
            status: .passed,
            failureCode: nil,
            latencyMilliseconds: 1.25,
            outputSHA256: HyMT2NegationShadowFileHasher.sha256UTF8("public output")
        )
    }

    private var approvedRootKeys: Set<String> {
        [
            "schemaVersion", "seed", "temperature", "threadCount", "modelSHA256",
            "helperSHA256", "backgroundLoad", "latencyControlled", "results",
        ]
    }

    private var approvedResultKeys: Set<String> {
        [
            "fixtureID", "encoding", "occurrenceCount", "status", "latencyMilliseconds",
            "outputSHA256",
        ]
    }
}
