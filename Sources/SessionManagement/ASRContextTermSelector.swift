import Foundation
import GlossaryAPI
import SettingsAPI

enum ASRContextTermSelector {
    static func prompt(
        from entries: [GlossaryEntry],
        mode: TranslationMode,
        limit: Int = 48
    ) -> String {
        let terms =
            switch mode {
            case .mandarinToEnglish: mandarinTerms(entries, requestedLimit: limit)
            case .englishToSimplifiedChinese: englishTerms(entries, requestedLimit: limit)
            }
        return unique(terms).prefix(max(0, limit)).joined(separator: ",")
    }

    private static func mandarinTerms(
        _ entries: [GlossaryEntry],
        requestedLimit: Int
    ) -> [String] {
        let candidates = entries.map {
            MandarinCandidate(text: $0.source, required: $0.enforcement == .required)
        }.filter { safeMandarinHotword($0.text) }
        let byKey = Dictionary(candidates.map { ($0.text, $0) }) { first, _ in first }
        let core = mandarinCoreTerms.map {
            byKey[$0] ?? MandarinCandidate(text: $0, required: true)
        }
        let coreKeys = Set(core.map(\.text))
        let custom = candidates.filter {
            !coreKeys.contains($0.text) && !mandarinBuiltInSourceTerms.contains($0.text)
        }.sorted {
            if $0.required != $1.required { return $0.required }
            if $0.text.count != $1.text.count { return $0.text.count < $1.text.count }
            return $0.text.localizedStandardCompare($1.text) == .orderedAscending
        }
        return Array((core + custom).prefix(min(max(0, requestedLimit), maximumMandarinTerms)))
            .map(\.text)
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

    private static func safeEnglishHotword(_ term: String) -> Bool {
        guard !term.isEmpty, term.count <= 32 else { return false }
        guard !term.contains(where: englishSeparators.contains) else { return false }
        return term.split(whereSeparator: \.isWhitespace).count <= 3
    }

    private static func safeMandarinHotword(_ term: String) -> Bool {
        guard !term.isEmpty, term.count <= 8 else { return false }
        return !term.contains(where: mandarinSeparators.contains)
    }

    private static let maximumMandarinTerms = 18
    private static let maximumEnglishTerms = 18
    private static let mandarinSeparators = Set<Character>([",", "，", "、", ";", "；", "\n"])
    private static let englishSeparators = Set<Character>([",", "，", "、", ";", "；", "\n"])
    private static let mandarinCoreTerms = [
        "麦基洗德", "撒冷", "亚伯拉罕", "至高神", "祭司", "基督耶稣", "救赎", "恩典",
        "本乎恩典", "因着信", "称义", "成圣", "主耶稣基督", "圣灵", "父子圣灵",
    ]
    private static let mandarinBuiltInSourceTerms = Set(DefaultGlossary.entries.map(\.source))
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

    private struct MandarinCandidate {
        let text: String
        let required: Bool
    }
}
