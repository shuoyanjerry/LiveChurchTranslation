import Foundation
import TranslationAPI

enum HyMT2ObservedPronounClass: String, Equatable, Sendable {
    case female
    case male
    case singularThey
    case punctuatedFemale
    case punctuatedMale
    case punctuatedSingularThey
    case sourceGlyph
    case chinese
    case singleOtherToken
    case multiToken
    case other
    case missing
}

enum HyMT2PronounRealizationClass: String, Equatable, Sendable {
    case singularThey
    case feminine
    case masculine
}

struct HyMT2PronounRealization: Equatable, Sendable {
    let occurrence: HyMT2PronounOccurrence
    let realizationClass: HyMT2PronounRealizationClass
}

enum HyMT2PronounRealizationClassifier {
    static func observe(_ value: String) -> HyMT2ObservedPronounClass {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return .missing }
        if let direct = directPronounClass(normalized) { return direct }
        if let punctuated = punctuatedPronounClass(normalized) { return punctuated }
        return nonPronounClass(normalized)
    }

    private static func directPronounClass(_ value: String) -> HyMT2ObservedPronounClass? {
        if singularTheyForms.contains(value) { return .singularThey }
        if feminineForms.contains(value) { return .female }
        if masculineForms.contains(value) { return .male }
        return nil
    }

    private static func nonPronounClass(_ value: String) -> HyMT2ObservedPronounClass {
        if isPunctuatedSourceGlyph(value) { return .sourceGlyph }
        if value.unicodeScalars.contains(where: { $0.properties.isIdeographic }) {
            return .chinese
        }
        let tokens = lexicalTokens(value)
        if tokens.count > 1 { return .multiToken }
        if tokens.count == 1, value.allSatisfy(\.isLetter) {
            return .singleOtherToken
        }
        return .other
    }

    static func acceptedClass(
        _ observed: HyMT2ObservedPronounClass,
        for resolution: TranslationPronounResolution
    ) -> HyMT2PronounRealizationClass? {
        switch resolution {
        case .unresolvedSpokenMandarin:
            return observed == .singularThey
                ? HyMT2PronounRealizationClass.singularThey : nil
        case .verifiedFemale:
            return observed == .female
                ? HyMT2PronounRealizationClass.feminine : nil
        case .verifiedMale, .verifiedDeity:
            return observed == .male
                ? HyMT2PronounRealizationClass.masculine : nil
        }
    }

    private static let singularTheyForms = Set([
        "they", "them", "their", "theirs", "themself", "themselves",
    ])
    private static let feminineForms = Set(["she", "her", "hers", "herself"])
    private static let masculineForms = Set(["he", "him", "his", "himself"])
    private static let sourceGlyphs = Set(["他", "她", "祂"])

    private static func punctuatedPronounClass(
        _ value: String
    ) -> HyMT2ObservedPronounClass? {
        let tokens = lexicalTokens(value)
        guard hasOnlyLettersAndFormatting(value), tokens.count == 1,
            let token = tokens.first
        else { return nil }
        if feminineForms.contains(token) { return .punctuatedFemale }
        if masculineForms.contains(token) { return .punctuatedMale }
        if singularTheyForms.contains(token) { return .punctuatedSingularThey }
        return nil
    }

    private static func isPunctuatedSourceGlyph(_ value: String) -> Bool {
        let tokens = lexicalTokens(value)
        guard hasOnlyLettersAndFormatting(value), tokens.count == 1,
            let token = tokens.first
        else { return false }
        return sourceGlyphs.contains(token)
    }

    private static func hasOnlyLettersAndFormatting(_ value: String) -> Bool {
        value.allSatisfy { $0.isLetter || $0.isWhitespace || $0.isPunctuation }
    }

    private static func lexicalTokens(_ value: String) -> [String] {
        value.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}
