import ASRAPI
import ASRNormalizationAPI
import Foundation
import GlossaryAPI
import SettingsAPI
import TranscriptAPI
import TranslationAPI

extension UtteranceProcessor {
    func asrPrompt(from entries: [GlossaryEntry], mode: TranslationMode) -> String {
        ASRContextTermSelector.prompt(from: entries, mode: mode)
    }

    func normalizedRecognition(
        _ utterance: RecognizedUtterance,
        entries: [GlossaryEntry],
        mode: TranslationMode
    ) -> (utterance: RecognizedUtterance, audit: TranscriptSourceAudit) {
        let result = dependencies.asrNormalizer.normalizeWithAudit(
            utterance.text,
            using: mode == .mandarinToEnglish ? normalizationRules(from: entries) : []
        )
        let normalized = RecognizedUtterance(
            id: utterance.id,
            sourceSegmentID: utterance.sourceSegmentID,
            rawText: utterance.rawText,
            text: result.normalizedText,
            confidence: utterance.confidence,
            startedAt: utterance.startedAt,
            endedAt: utterance.endedAt
        )
        let corrections = result.changes.map {
            TranscriptSourceCorrection(
                observedText: $0.recognitionAlias,
                replacementText: $0.canonicalText,
                kind: .recognitionNormalization
            )
        }
        return (
            normalized,
            TranscriptSourceAudit(rawText: utterance.rawText, corrections: corrections)
        )
    }

    func matchedTerms(
        in source: String,
        entries: [GlossaryEntry],
        mode: TranslationMode
    ) -> [TranslationTerm] {
        let glossaryTerms = translatedTerms(entries, mode: mode)
            .filter { entry in
                ([entry.source] + entry.sourceAliases).contains {
                    source.localizedStandardContains($0)
                }
            }
        let scriptureTerms = ScriptureBookTermCatalog.matchedTerms(in: source, mode: mode)
        return (glossaryTerms + scriptureTerms)
            .sorted { $0.source.count > $1.source.count }
    }

    private func translatedTerms(
        _ entries: [GlossaryEntry],
        mode: TranslationMode
    ) -> [TranslationTerm] {
        entries.map { entry in
            switch mode {
            case .mandarinToEnglish:
                TranslationTerm(
                    source: entry.source,
                    target: entry.target,
                    sourceAliases: entry.sourceAliases,
                    acceptedTargets: entry.targetVariants,
                    requirement: requirement(entry)
                )
            case .englishToSimplifiedChinese:
                TranslationTerm(
                    source: entry.target,
                    target: entry.source,
                    sourceAliases: entry.targetVariants,
                    acceptedTargets: entry.sourceAliases,
                    requirement: requirement(entry)
                )
            }
        }
    }

    private func requirement(_ entry: GlossaryEntry) -> TranslationTermRequirement {
        entry.enforcement == .required ? .required : .preferred
    }

    private func normalizationRules(
        from entries: [GlossaryEntry]
    ) -> [ASRNormalizationRule] {
        entries.flatMap { entry in
            entry.recognitionAliases.map {
                ASRNormalizationRule(
                    recognitionAlias: $0,
                    canonicalText: entry.source
                )
            }
        }
    }
}

enum ASRContextTermSelector {
    static func prompt(
        from entries: [GlossaryEntry],
        mode: TranslationMode,
        limit: Int = 48
    ) -> String {
        let terms: [String]
        switch mode {
        case .mandarinToEnglish:
            terms = entries.map(\.source).sorted(by: longestFirst)
        case .englishToSimplifiedChinese:
            terms = englishTerms(entries, requestedLimit: limit)
        }
        return unique(terms).prefix(max(0, limit)).joined(separator: ",")
    }

    private static func englishTerms(
        _ entries: [GlossaryEntry],
        requestedLimit: Int
    ) -> [String] {
        let candidates = entries.flatMap { entry in
            ([entry.target] + entry.targetVariants).map {
                EnglishCandidate(text: $0, required: entry.enforcement == .required)
            }
        }.filter { safeEnglishHotword($0.text) }
        let byKey = Dictionary(candidates.map { ($0.text.lowercased(), $0) }) { first, _ in first }
        let core = englishCoreTerms.compactMap { byKey[$0.lowercased()] }
        let coreKeys = Set(core.map { $0.text.lowercased() })
        let dynamic = candidates.filter { !coreKeys.contains($0.text.lowercased()) }.sorted {
            if $0.required != $1.required { return $0.required }
            let leftWords = $0.text.split(whereSeparator: \.isWhitespace).count
            let rightWords = $1.text.split(whereSeparator: \.isWhitespace).count
            if leftWords != rightWords { return leftWords < rightWords }
            if $0.text.count != $1.text.count { return $0.text.count < $1.text.count }
            return $0.text.localizedStandardCompare($1.text) == .orderedAscending
        }
        return Array((core + dynamic).prefix(min(max(0, requestedLimit), maximumEnglishTerms)))
            .map(\.text)
    }

    private static func unique(_ terms: [String]) -> [String] {
        var seen: Set<String> = []
        return terms.filter { seen.insert($0.lowercased()).inserted }
    }

    private static func longestFirst(_ left: String, _ right: String) -> Bool {
        if left.count != right.count { return left.count > right.count }
        return left.localizedStandardCompare(right) == .orderedAscending
    }

    private static func safeEnglishHotword(_ term: String) -> Bool {
        guard !term.isEmpty, term.count <= 32 else { return false }
        guard !term.contains(where: englishSeparators.contains) else { return false }
        return term.split(whereSeparator: \.isWhitespace).count <= 3
    }

    private static let maximumEnglishTerms = 18
    private static let englishSeparators = Set<Character>([",", "，", "、", ";", "；", "\n"])
    private static let englishCoreTerms = [
        "salvation", "grace", "justification", "sanctification",
        "the Holy Spirit", "the Trinity", "resurrection", "atonement", "repentance",
        "prayer", "pray", "prays", "praying", "praise", "praises", "praising", "church",
        "gracious",
    ]

    private struct EnglishCandidate {
        let text: String
        let required: Bool
    }
}
