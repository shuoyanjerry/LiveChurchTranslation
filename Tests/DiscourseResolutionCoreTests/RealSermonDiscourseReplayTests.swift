import DiscourseResolutionAPI
import DiscourseResolutionCore
import Foundation
import Testing

@Suite("Local real-sermon discourse qualification")
struct RealSermonDiscourseReplayTests {
    @Test(
        "replays manually reviewed Mandarin pronoun cases",
        .enabled(
            if: ProcessInfo.processInfo.environment["MANDARIN_PRONOUN_GOLDEN"] != nil,
            "Requires a private, non-redistributed golden manifest."
        )
    )
    func replayPrivateGoldens() throws {
        guard
            let path = ProcessInfo.processInfo.environment["MANDARIN_PRONOUN_GOLDEN"]
        else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: data)
        #expect(fixtures.count >= 4)

        let resolver = DiscourseResolver()
        for fixture in fixtures {
            let result = resolver.resolve(
                DiscourseResolutionRequest(
                    currentSequence: fixture.sequence,
                    currentText: fixture.current,
                    verifiedTurns: fixture.context.map {
                        VerifiedDiscourseTurn(sequence: $0.sequence, text: $0.text)
                    }
                )
            )
            #expect(result.resolvedText == fixture.expected, "fixture: \(fixture.name)")
            #expect(
                result.corrections.count == fixture.expectedCorrectionCount,
                "fixture: \(fixture.name)"
            )
        }
        print("DISCOURSE_REAL_GOLDENS=\(fixtures.count)")
    }
}

private struct Fixture: Decodable {
    let name: String
    let sequence: Int
    let context: [Context]
    let current: String
    let expected: String
    let expectedCorrectionCount: Int
}

private struct Context: Decodable {
    let sequence: Int
    let text: String
}
