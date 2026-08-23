extension HyMT2SpacedCanonicalPronounParser {
    static func validateRealizations(
        _ bindings: [HyMT2SpacedCanonicalBinding],
        occurrences: [HyMT2PronounOccurrence]
    ) throws -> [HyMT2PronounRealization] {
        let byName = Dictionary(uniqueKeysWithValues: bindings.map { ($0.token.markerName, $0) })
        var realizations: [HyMT2PronounRealization] = []
        var issues: [OutputValidationIssue] = []
        for occurrence in occurrences {
            guard let binding = byName[occurrence.markerName] else { continue }
            if let accepted = HyMT2PronounRealizationClassifier.acceptedClass(
                binding.observedClass,
                for: occurrence.resolution
            ) {
                realizations.append(
                    HyMT2PronounRealization(
                        occurrence: occurrence,
                        realizationClass: accepted
                    )
                )
            } else {
                issues.append(
                    .wrongPronounRealization(
                        occurrence.identifier,
                        occurrence.sourceRange,
                        occurrence.resolution,
                        binding.observedClass
                    )
                )
            }
        }
        guard issues.isEmpty else { throw OutputValidationFailure(issues: issues) }
        return realizations
    }

    static func clean(
        _ output: String,
        bindings: [HyMT2SpacedCanonicalBinding]
    ) throws -> String {
        var result = ""
        var boundaries: [(offset: Int, shape: HyMT2SpacedCanonicalRightShape)] = []
        var cursor = output.startIndex
        for binding in bindings {
            result += output[cursor..<binding.removalRange.lowerBound]
            boundaries.append((result.utf8.count, binding.rightShape))
            cursor = binding.removalRange.upperBound
        }
        result += output[cursor...]
        let bytes = Array(result.utf8)
        guard boundaries.allSatisfy({ matches($0, in: bytes) }) else {
            throw OutputValidationFailure(issues: [.malformedPronounMarker])
        }
        return result
    }

    private static func matches(
        _ boundary: (offset: Int, shape: HyMT2SpacedCanonicalRightShape),
        in bytes: [UInt8]
    ) -> Bool {
        switch boundary.shape {
        case .lexicalContinuation:
            boundary.offset < bytes.count && bytes[boundary.offset] == 0x20
        case .commaContinuation:
            boundary.offset + 2 < bytes.count
                && bytes[boundary.offset] == 0x2C
                && bytes[boundary.offset + 1] == 0x20
                && isASCIILetter(bytes[boundary.offset + 2])
        case .terminalPeriod:
            boundary.offset + 1 == bytes.count && bytes[boundary.offset] == 0x2E
        case .terminalEnd:
            boundary.offset == bytes.count
        }
    }

    private static func isASCIILetter(_ byte: UInt8) -> Bool {
        (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
    }
}
