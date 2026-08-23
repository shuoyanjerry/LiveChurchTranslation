@testable import ASRQwen3
import Testing

@Suite("Qwen decode retry policy")
struct Qwen3DecodeRetryPolicyTests {
    @Test func retriesPromptOnlyOutputWithoutHotwords() {
        #expect(
            Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: Self.promptOnlyOutput,
                hotwords: Self.terms
            ) == .promptOnly
        )
    }

    @Test func retriesEnglishPromptEchoDespiteSentenceCaseAndPunctuation() {
        #expect(
            Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: "Salvation grace prayer praise atonement church.",
                hotwords: "salvation,grace,prayer,praise,atonement,church"
            ) == .promptOnly
        )
    }

    @Test func retriesTruncatedEnglishPromptSuffix() {
        #expect(
            Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: "Holy Spirit Trinity resurrection atonement prayer praise.",
                hotwords: "salvation,grace,Holy Spirit,Trinity,resurrection,atonement,prayer,praise"
            ) == .promptOnly
        )
    }

    @Test func doesNotRetryPromptPrefixWhenRecognizedBodyRemains() {
        let output = Self.promptOnlyOutput + "神爱世人。"

        #expect(
            Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: output,
                hotwords: Self.terms
            ) == nil
        )
    }

    @Test func neverRetriesWithoutHotwords() {
        #expect(
            !Qwen3DecodeRetryPolicy.shouldRetryWithoutHotwords(
                firstOutput: "",
                hotwords: ""
            )
        )
    }

    @Test func preservesTheOriginalEchoGuardAfterPromptOnlyFallback() {
        #expect(
            Qwen3DecodeRetryPolicy.outputGuardHotwords(
                after: .promptOnly,
                originalHotwords: Self.terms
            ) == Self.terms
        )
        #expect(
            Qwen3DecodeRetryPolicy.outputGuardHotwords(
                after: .pathologicalRepetition,
                originalHotwords: Self.terms
            ).isEmpty
        )
    }

    @Test func preservesTheExistingPathologicalRepetitionFallback() {
        #expect(
            Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: String(repeating: "我们有信心", count: 8),
                hotwords: Self.terms
            ) == .pathologicalRepetition
        )
    }

    private static let terms = "救恩,恩典,称义,因信称义,成圣,重生,赎罪,三位一体,圣灵"
    private static let promptOnlyOutput =
        "救恩 恩典 称义 因信称义 成圣 重生 赎罪 三位一体 圣灵。"
}
