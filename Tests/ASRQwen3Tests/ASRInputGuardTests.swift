@testable import ASRQwen3
import Testing

@Suite("Qwen ASR input guard")
struct ASRInputGuardTests {
    @Test func capsMoreThanFortyEightUniqueHotwordsWithoutTrapping() {
        let context = (0..<80).map { "术语\($0)" }.joined(separator: ",")

        let output = ASRInputGuard.hotwords(from: context, limit: 48)

        let words = output.split(separator: ",")
        #expect(words.count == 48)
        #expect(words.first == "术语0")
        #expect(words.last == "术语47")
    }

    @Test func removesDuplicatesAndBlankComponentsInStableOrder() {
        let output = ASRInputGuard.hotwords(
            from: "救恩, 恩典，救恩；\n因信称义;;",
            limit: 48
        )

        #expect(output == "救恩,恩典,因信称义")
    }

    @Test func nonPositiveLimitReturnsNoHotwords() {
        #expect(ASRInputGuard.hotwords(from: "救恩,恩典", limit: 0).isEmpty)
    }
}
