enum Qwen3DecodeRetryPolicy {
    static func retryReason(
        firstOutput: String,
        hotwords: String
    ) -> Qwen3DecodeRetryReason? {
        guard !hotwords.isEmpty else { return nil }
        if ASRInputGuard.isPromptOnlyHallucination(firstOutput, hotwords: hotwords) {
            return .promptOnly
        }
        if ASROutputGuard.hasPathologicalRepetition(firstOutput) {
            return .pathologicalRepetition
        }
        if ASRInputGuard.promptEchoPrefixTermCount(firstOutput, hotwords: hotwords) != nil {
            return .promptPrefix
        }
        return nil
    }

    static func shouldRetryWithoutHotwords(
        firstOutput: String,
        hotwords: String
    ) -> Bool {
        retryReason(firstOutput: firstOutput, hotwords: hotwords) != nil
    }

    static func outputGuardHotwords(
        after reason: Qwen3DecodeRetryReason,
        originalHotwords: String
    ) -> String {
        switch reason {
        case .promptOnly, .promptPrefix: originalHotwords
        case .pathologicalRepetition: ""
        }
    }

    static func selection(
        firstOutput: String,
        fallbackOutput: String,
        hotwords: String,
        reason: Qwen3DecodeRetryReason
    ) -> Qwen3DecodeSelection {
        let keepsFirstPrefixOutput =
            reason == .promptPrefix
            && !isUsablePrefixFallback(
                fallbackOutput,
                replacing: firstOutput,
                hotwords: hotwords
            )
        if keepsFirstPrefixOutput {
            return Qwen3DecodeSelection(rawText: firstOutput, outputGuardHotwords: "")
        }
        return Qwen3DecodeSelection(
            rawText: fallbackOutput,
            outputGuardHotwords: outputGuardHotwords(
                after: reason,
                originalHotwords: hotwords
            )
        )
    }

    private static func isUsablePrefixFallback(
        _ output: String,
        replacing firstOutput: String,
        hotwords: String
    ) -> Bool {
        guard !output.isEmpty,
            !ASROutputGuard.hasPathologicalRepetition(output),
            !ASRInputGuard.isKnownNonspeechHallucination(output),
            !ASRInputGuard.isPromptOnlyHallucination(output, hotwords: hotwords),
            ASRInputGuard.promptEchoPrefixTermCount(output, hotwords: hotwords) == nil,
            let firstBodyLength = ASRInputGuard.promptEchoBodyLength(
                firstOutput,
                hotwords: hotwords
            )
        else { return false }
        return ASRInputGuard.compactedLength(output) >= firstBodyLength
    }
}

enum Qwen3DecodeRetryReason: Equatable {
    case promptOnly
    case promptPrefix
    case pathologicalRepetition
}

struct Qwen3DecodeSelection {
    let rawText: String
    let outputGuardHotwords: String
}
