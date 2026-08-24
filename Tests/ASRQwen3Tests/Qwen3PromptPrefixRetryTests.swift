@testable import ASRQwen3
import Testing

@Suite("Qwen prompt-prefix retry policy")
struct Qwen3PromptPrefixRetryTests {
    @Test func retriesPromptPrefixWhenRecognizedBodyRemains() {
        let output = Self.promptOnlyOutput + "神爱世人。"

        #expect(
            Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: output,
                hotwords: Self.terms
            ) == .promptPrefix
        )
    }

    @Test func usesUnpromptedFallbackInsteadOfDeletingPromptedText() {
        let first = Self.promptOnlyOutput + "神爱世人。"
        let selection = Qwen3DecodeRetryPolicy.selection(
            firstOutput: first,
            fallbackOutput: "神爱世人。",
            hotwords: Self.terms,
            reason: .promptPrefix
        )

        #expect(selection.rawText == "神爱世人。")
        #expect(selection.outputGuardHotwords == Self.terms)
    }

    @Test func usesUnpromptedFallbackForEverySmallPromptSize() {
        let terms = ["救恩", "恩典", "称义", "成圣", "圣灵"]

        for count in 1...terms.count {
            let hotwords = terms.prefix(count).joined(separator: ",")
            let first = terms.prefix(count).joined(separator: "，") + "。神爱世人。"
            let reason = Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: first,
                hotwords: hotwords
            )
            let selection = Qwen3DecodeRetryPolicy.selection(
                firstOutput: first,
                fallbackOutput: "神爱世人。",
                hotwords: hotwords,
                reason: reason ?? .pathologicalRepetition
            )

            #expect(reason == .promptPrefix)
            #expect(selection.rawText == "神爱世人。")
        }
    }

    @Test func preservesRealOpeningThatExactlyStartsWithAHotword() {
        let sentence = "救恩是神白白赐下的恩典。"
        let reason = Qwen3DecodeRetryPolicy.retryReason(
            firstOutput: sentence,
            hotwords: "救恩"
        )
        let selection = Qwen3DecodeRetryPolicy.selection(
            firstOutput: sentence,
            fallbackOutput: sentence,
            hotwords: "救恩",
            reason: reason ?? .pathologicalRepetition
        )

        #expect(reason == .promptPrefix)
        #expect(selection.rawText == sentence)
    }

    @Test func preservesCompleteFirstDecodeWhenPrefixFallbackIsUnusable() {
        let first = Self.promptOnlyOutput + "神爱世人。"
        let selection = Qwen3DecodeRetryPolicy.selection(
            firstOutput: first,
            fallbackOutput: "系统。",
            hotwords: Self.terms,
            reason: .promptPrefix
        )

        #expect(selection.rawText == first)
        #expect(selection.outputGuardHotwords.isEmpty)
    }

    private static let terms = "救恩,恩典,称义,因信称义,成圣,重生,赎罪,三位一体,圣灵"
    private static let promptOnlyOutput =
        "救恩 恩典 称义 因信称义 成圣 重生 赎罪 三位一体 圣灵。"
}

extension Qwen3PromptPrefixRetryTests {
    @Test func preservesCompleteFirstDecodeWhenFallbackIsSubstantiallyShorter() {
        let first = "救恩是神白白赐下的恩典。"
        let selection = Qwen3DecodeRetryPolicy.selection(
            firstOutput: first,
            fallbackOutput: "恩典。",
            hotwords: "救恩",
            reason: .promptPrefix
        )

        #expect(selection.rawText == first)
        #expect(selection.outputGuardHotwords.isEmpty)
    }

    @Test func preservesFirstDecodeWhenFallbackStillHasAPromptPrefix() {
        let first = Self.promptOnlyOutput + "神爱世人。"
        let fallback = "救恩，恩典，称义，因信称义，成圣，重生。神爱世人。"
        let selection = Qwen3DecodeRetryPolicy.selection(
            firstOutput: first,
            fallbackOutput: fallback,
            hotwords: Self.terms,
            reason: .promptPrefix
        )

        #expect(selection.rawText == first)
        #expect(selection.outputGuardHotwords.isEmpty)
    }

    @Test func acceptsFallbackThatRetainsTheWholeRecognizedBody() {
        let first = "救恩，恩典，称义。今天我们一同来看神的话。"
        let fallback = "今天，我们一同来看神的话！"
        let selection = Qwen3DecodeRetryPolicy.selection(
            firstOutput: first,
            fallbackOutput: fallback,
            hotwords: "救恩,恩典,称义",
            reason: .promptPrefix
        )

        #expect(selection.rawText == fallback)
        #expect(selection.outputGuardHotwords == "救恩,恩典,称义")
    }

    @Test func preservesFirstDecodeWhenFallbackRetainsOnlyThreeQuartersOfBody() {
        let first = "salvation abcdefgh."
        let fallback = "abcdef."
        let selection = Qwen3DecodeRetryPolicy.selection(
            firstOutput: first,
            fallbackOutput: fallback,
            hotwords: "salvation",
            reason: .promptPrefix
        )

        #expect(selection.rawText == first)
        #expect(selection.outputGuardHotwords.isEmpty)
    }

    @Test func shortPartialPrefixDoesNotTriggerRetry() {
        #expect(
            Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: "救恩，恩典，今天我们一同来看神的话。",
                hotwords: "救恩,恩典,称义,成圣,圣灵"
            ) == nil
        )
    }

}
