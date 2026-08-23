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
        reason == .promptOnly ? originalHotwords : ""
    }
}

enum Qwen3DecodeRetryReason: Equatable {
    case promptOnly
    case pathologicalRepetition
}

struct Qwen3DecodeSelection {
    let rawText: String
    let outputGuardHotwords: String
}
