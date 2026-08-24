import Foundation
import TranslationAPI

enum HyMT2BestEffortExtractor {
    static func assess(
        _ output: String,
        failure: OutputValidationFailure,
        input: HyMT2PreparedTranslationInput,
        phase: HyMT2AttemptPhase? = nil
    ) -> HyMT2AssessedOutput? {
        guard !failure.issues.contains(.contextReplay) else { return nil }
        guard
            let target = publishableTarget(
                output,
                input: input
            )
        else {
            return nil
        }
        let issues = mergedIssues(failure.issues, target: target, input: input)
        let codes = issues.compactMap(\.translationReviewCode)
        let review = TranslationReview(
            issueCodes: codes.isEmpty ? ["quality.validation_failed"] : codes
        )
        return HyMT2AssessedOutput(
            target: target,
            review: review,
            validationIssueCount: issues.count,
            pronounRealizations: failure.pronounRealizations,
            reviewedPhase: phase
        )
    }

    private static func mergedIssues(
        _ initial: [OutputValidationIssue],
        target: String,
        input: HyMT2PreparedTranslationInput
    ) -> [OutputValidationIssue] {
        let fidelity = HyMT2FidelityValidator.issues(
            target: target,
            source: input.source,
            requiredTerms: input.terms,
            sourceLanguage: input.sourceLanguage,
            targetLanguage: input.targetLanguage,
            context: input.context
        )
        return fidelity.reduce(into: initial) { issues, issue in
            if !issues.contains(issue) { issues.append(issue) }
        }
    }
}

extension HyMT2BestEffortExtractor {
    private static func publishableTarget(
        _ output: String,
        input: HyMT2PreparedTranslationInput
    ) -> String? {
        let canonical = HyMT2PronounMarkerTokenizer.tokens(in: output)
        let flat = HyMT2FlatPronounTokenizer.tokens(in: output)
        let ranges = canonical.map(\.range) + flat.map(\.removableRange)
        let withoutProtocol = removing(ranges, from: output)
        guard
            let withoutMetaWrapper = sanitizedMetaWrapper(
                withoutProtocol,
                source: input.source
            ),
            !HyMT2PromptControlDelimiter.occurs(in: withoutMetaWrapper),
            !HyMT2PronounProtocolResidualValidator.containsProtocolFragment(
                in: withoutMetaWrapper,
                plan: input.pronounPlan
            )
        else { return nil }

        let normalized = HyMT2TargetOrthographyNormalizer.normalize(
            normalizedWhitespace(in: withoutMetaWrapper),
            language: input.targetLanguage
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
            !containsGuidedPronounAlternativeList(normalized, input: input),
            !HyMT2MetaText.isProbableSourceEcho(
                target: normalized,
                source: input.source,
                sourceLanguage: input.sourceLanguage,
                targetLanguage: input.targetLanguage
            )
        else { return nil }
        return normalized
    }

    private static func containsGuidedPronounAlternativeList(
        _ target: String,
        input: HyMT2PreparedTranslationInput
    ) -> Bool {
        input.pronounPlan != nil
            && input.targetLanguage.lowercased().hasPrefix("en")
            && HyMT2PronounAlternativeListDetector.containsAlternativeList(in: target)
    }

    private static func removing(
        _ ranges: [Range<String.Index>],
        from output: String
    ) -> String {
        var result = ""
        var cursor = output.startIndex
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            guard range.lowerBound >= cursor else { return "" }
            result += output[cursor..<range.lowerBound]
            cursor = range.upperBound
        }
        result += output[cursor...]
        return result
    }

    private static func normalizedWhitespace(in value: String) -> String {
        value.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
    }

    private static func sanitizedMetaWrapper(_ value: String, source: String) -> String? {
        let separators = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: ":：-")
        )
        var candidate = HyMT2MetaText.normalized(value)
        for _ in 0..<4 {
            let lower = candidate.lowercased()
            guard !HyMT2MetaText.blocksPresentation(candidate, source: source) else {
                return nil
            }
            guard let prefix = HyMT2MetaText.removablePrefixes.first(where: lower.hasPrefix) else {
                return candidate
            }
            let boundary = candidate.index(candidate.startIndex, offsetBy: prefix.count)
            if !prefix.hasSuffix(":") {
                guard boundary < candidate.endIndex,
                    ":：-".contains(candidate[boundary])
                else { return candidate }
            }
            candidate = HyMT2MetaText.normalized(
                String(candidate[boundary...]).trimmingCharacters(in: separators)
            )
            guard !candidate.isEmpty else { return nil }
        }
        return nil
    }
}
