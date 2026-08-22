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

    @Test func rejectsObservedPromptListEchoFromNonspeechAudio() {
        let terms = "救恩,恩典,称义,因信称义,成圣,重生,赎罪,三位一体,圣灵"
        let output = "救恩 恩典 称义 因信称义 成圣 重生 赎罪 三位一体 圣灵。"

        #expect(ASRInputGuard.isPromptOnlyHallucination(output, hotwords: terms))
    }

    @Test func keepsNaturalSentenceThatUsesSeveralHotwords() {
        let terms = "救恩,恩典,称义,因信称义,成圣,重生,赎罪,三位一体,圣灵"
        let sentence = "救恩本乎恩典，因信称义以后，圣灵也在我们里面作成圣的工作。"

        #expect(!ASRInputGuard.isPromptOnlyHallucination(sentence, hotwords: terms))
        #expect(ASRInputGuard.removingPromptEchoPrefix(sentence, hotwords: terms) == sentence)
    }

    @Test func stripsPromptEchoPrefixButKeepsRecognizedSermonText() {
        let terms = "救恩,恩典,称义,因信称义,成圣,重生,赎罪,三位一体,圣灵,团契,事奉,圣餐,洗礼,祂"
        let output = "救恩恩典称义，因信称义，成圣重生，赎罪，三位一体，圣灵，团契，事奉，圣餐，洗礼，神的应许使我们有分于祂的性情。"

        #expect(
            ASRInputGuard.removingPromptEchoPrefix(output, hotwords: terms)
                == "神的应许使我们有分于祂的性情。"
        )
    }

    @Test(arguments: ["系统", "系统。", "system", "SYSTEM."])
    func rejectsKnownQwenNonspeechSentinel(_ text: String) {
        #expect(ASRInputGuard.isKnownNonspeechHallucination(text))
    }

    @Test func keepsNaturalSentenceContainingSystem() {
        #expect(!ASRInputGuard.isKnownNonspeechHallucination("这个系统需要更新。"))
    }
}
