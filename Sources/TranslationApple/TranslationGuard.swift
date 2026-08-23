import Foundation
import TranslationAPI

enum TranslationGuard {
    static func validate(_ target: String, for request: TranslationRequest) throws -> String {
        // Apple's system Translation API does not expose occurrence-level alignment.
        // Accepting its output here would silently discard the API contract for
        // unresolved/verified Mandarin pronouns.
        guard request.pronounGuidance.isEmpty else {
            throw TranslationProviderError.invalidOutput
        }
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationProviderError.invalidOutput }

        let sourceCount = max(1, request.sourceText.count)
        let targetCount = trimmed.count
        guard targetCount >= max(1, sourceCount / 5), targetCount <= sourceCount * 10 + 80 else {
            throw TranslationProviderError.invalidOutput
        }

        let lowercased = trimmed.lowercased()
        let forbiddenPrefixes = [
            "here is the translation", "the translation is", "summary:", "i'm sorry",
        ]
        guard !forbiddenPrefixes.contains(where: lowercased.hasPrefix) else {
            throw TranslationProviderError.invalidOutput
        }
        return trimmed
    }
}
