import Foundation
import TranslationAPI

enum HyMT2PronounDeterministicRepairer {
    static func repair(
        _ output: String,
        plan: HyMT2PronounPlan?
    ) -> String {
        guard let plan else { return output }
        let tokens = HyMT2PronounMarkerTokenizer.tokens(in: output)
        guard !tokens.isEmpty,
            (try? HyMT2PronounMarkerTokenizer.validate(
                output,
                tokens: tokens,
                expected: plan.occurrences
            )) != nil,
            let bindings = bindings(tokens, in: output),
            bindings.count == plan.occurrences.count
        else { return output }

        let byName = Dictionary(uniqueKeysWithValues: bindings.map { ($0.markerName, $0) })
        var replacements: [(Range<String.Index>, String)] = []
        for occurrence in plan.occurrences {
            guard let binding = byName[occurrence.markerName],
                let replacement = replacement(for: binding, occurrence: occurrence)
            else { return output }
            if replacement != String(output[binding.pronounRange]) {
                replacements.append((binding.pronounRange, replacement))
            }
        }
        return replacing(replacements, in: output)
    }

    private static func bindings(
        _ tokens: [HyMT2PronounAnchorToken],
        in output: String
    ) -> [HyMT2PronounRepairBinding]? {
        var result: [HyMT2PronounRepairBinding] = []
        var usedRanges: [Range<String.Index>] = []
        for token in tokens {
            guard let binding = binding(token, in: output),
                !usedRanges.contains(where: { $0.overlaps(binding.pronounRange) })
            else { return nil }
            usedRanges.append(binding.pronounRange)
            result.append(binding)
        }
        return result
    }

    private static func binding(
        _ token: HyMT2PronounAnchorToken,
        in output: String
    ) -> HyMT2PronounRepairBinding? {
        var wordEnd = token.range.lowerBound
        if wordEnd > output.startIndex {
            let previous = output.index(before: wordEnd)
            if output[previous] == " " {
                wordEnd = previous
            }
        }
        var wordStart = wordEnd
        while wordStart > output.startIndex {
            let previous = output.index(before: wordStart)
            guard HyMT2PronounTokenBoundary.isASCIILetter(output[previous]) else { break }
            wordStart = previous
        }
        let range = wordStart..<wordEnd
        guard !range.isEmpty,
            HyMT2PronounTokenBoundary.hasComplete(range, in: output),
            HyMT2PronounTokenBoundary.hasAllowedRight(
                after: token.range.upperBound,
                in: output
            ),
            PronounForm(rawValue: String(output[range]).lowercased()) != nil
        else { return nil }
        return HyMT2PronounRepairBinding(
            markerName: token.markerName,
            pronounRange: range,
            word: String(output[range]),
            subjectAgreementIsNumberInvariant:
                HyMT2SubjectAgreementGuard.isNumberInvariant(
                    after: token.range.upperBound,
                    in: output
                )
        )
    }

    private static func replacing(
        _ replacements: [(Range<String.Index>, String)],
        in output: String
    ) -> String {
        var result = output
        for (range, replacement) in replacements.sorted(by: {
            $0.0.lowerBound > $1.0.lowerBound
        }) {
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}

struct HyMT2PronounRepairBinding {
    let markerName: String
    let pronounRange: Range<String.Index>
    let word: String
    let subjectAgreementIsNumberInvariant: Bool
}
