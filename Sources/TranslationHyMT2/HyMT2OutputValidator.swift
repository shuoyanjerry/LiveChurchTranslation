import Foundation
import TranslationAPI

enum OutputValidationIssue: Equatable, Sendable {
    case empty
    case implausibleLength
    case metaText
    case missingTerm(String)
    case missingNumber(String)
    case missingNegation
    case malformedScriptureReference

    var description: String {
        switch self {
        case .empty: "empty output"
        case .implausibleLength: "implausible output length"
        case .metaText: "model commentary or instruction text"
        case .missingTerm(let term): "missing required term: \(term)"
        case .missingNumber(let number): "missing number: \(number)"
        case .missingNegation: "source negation was not preserved"
        case .malformedScriptureReference: "Scripture reference was not preserved"
        }
    }
}

struct OutputValidationFailure: Error, Equatable, Sendable {
    let issues: [OutputValidationIssue]
}

enum HyMT2OutputValidator {
    static func validate(
        _ output: String,
        source: String,
        requiredTerms: [TranslationTerm]
    ) throws -> String {
        let target = output.trimmingCharacters(in: .whitespacesAndNewlines)
        var issues: [OutputValidationIssue] = []
        if target.isEmpty { issues.append(.empty) }
        if !plausibleLength(target, source: source) { issues.append(.implausibleLength) }
        if containsMetaText(target) { issues.append(.metaText) }
        issues.append(contentsOf: missingTerms(in: target, required: requiredTerms))
        issues.append(contentsOf: missingNumbers(in: target, source: source))
        if containsNegation(source), !containsEnglishNegation(target) {
            issues.append(.missingNegation)
        }
        if containsScriptureReference(source), !containsEnglishScriptureReference(target) {
            issues.append(.malformedScriptureReference)
        }
        guard issues.isEmpty else { throw OutputValidationFailure(issues: issues) }
        return target
    }

    private static func plausibleLength(_ target: String, source: String) -> Bool {
        guard !target.isEmpty else { return false }
        let sourceCount = max(1, source.count)
        return target.count >= max(1, sourceCount / 5)
            && target.count <= sourceCount * 10 + 80
    }

    private static func containsMetaText(_ target: String) -> Bool {
        let lower = target.lowercased()
        let prefixes = [
            "here is the translation", "the translation is", "translation:",
            "translated result:", "as an ai", "i cannot translate", "source text:",
            "reference the following translations",
        ]
        return prefixes.contains(where: lower.hasPrefix)
    }

    private static func missingTerms(
        in target: String,
        required: [TranslationTerm]
    ) -> [OutputValidationIssue] {
        required.compactMap { term in
            target.range(
                of: term.target,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == nil ? .missingTerm(term.target) : nil
        }
    }

    private static func missingNumbers(
        in target: String,
        source: String
    ) -> [OutputValidationIssue] {
        let sourceNumbers = digitRuns(in: source)
        var remaining = digitRuns(in: target)
        return sourceNumbers.compactMap { number in
            guard let index = remaining.firstIndex(of: number) else {
                return .missingNumber(number)
            }
            remaining.remove(at: index)
            return nil
        }
    }

    private static func digitRuns(in text: String) -> [String] {
        matches(pattern: #"\d+"#, in: text)
    }

    private static func containsNegation(_ source: String) -> Bool {
        ["没有", "并非", "不是", "不可", "不能", "不要", "不得", "从未", "未曾", "不"]
            .contains(where: source.contains)
    }

    private static func containsEnglishNegation(_ target: String) -> Bool {
        let words = matches(pattern: #"[A-Za-z]+(?:'[A-Za-z]+)?"#, in: target.lowercased())
        let direct = Set(["not", "no", "never", "without", "neither", "nor", "cannot"])
        return words.contains(where: { direct.contains($0) || $0.hasSuffix("n't") })
    }

    private static func containsScriptureReference(_ source: String) -> Bool {
        !matches(pattern: #"[0-9零〇一二两三四五六七八九十百千]+章[0-9零〇一二两三四五六七八九十百千]+节"#, in: source).isEmpty
    }

    private static func containsEnglishScriptureReference(_ target: String) -> Bool {
        !matches(pattern: #"\d+\s*:\s*\d+"#, in: target).isEmpty
            || (target.localizedCaseInsensitiveContains("chapter")
                && target.localizedCaseInsensitiveContains("verse"))
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
