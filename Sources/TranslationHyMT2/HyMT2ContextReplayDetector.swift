import Foundation
import TranslationAPI

enum HyMT2ContextReplayKind: Equatable, Sendable {
    case normalizedExact
    case highOverlap
}

struct HyMT2ContextReplayDetector: Sendable {
    static func detect(
        candidateTarget: String,
        recentContext: [TranslationContextEntry]
    ) -> HyMT2ContextReplayKind? {
        let candidate = Fingerprint(candidateTarget)
        guard candidate.isEligibleForExactComparison else { return nil }

        for entry in recentContext.reversed() {
            let previous = Fingerprint(entry.targetText)
            if isExactMatch(candidate, previous) {
                return .normalizedExact
            }
            if candidate.isHighOverlap(with: previous) {
                return .highOverlap
            }
        }
        return nil
    }

    private static func isExactMatch(
        _ candidate: Fingerprint,
        _ previous: Fingerprint
    ) -> Bool {
        previous.isEligibleForExactComparison
            && candidate.scalars == previous.scalars
    }
}

private struct Fingerprint {
    let scalars: [UInt32]
    let shingles: [[UInt32]: Int]
    let shingleCount: Int
    let cjkScalarCount: Int

    init(_ text: String) {
        let compatible = text.precomposedStringWithCompatibilityMapping
        let folded = compatible.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        scalars = folded.unicodeScalars.compactMap {
            CharacterSet.alphanumerics.contains($0) ? $0.value : nil
        }
        cjkScalarCount = scalars.filter(Self.isCJK).count
        shingles = Self.shingles(in: scalars)
        shingleCount = max(0, scalars.count - Self.shingleWidth + 1)
    }

    var isEligibleForExactComparison: Bool {
        let minimumScalars =
            isPredominantlyCJK
            ? Self.minimumCJKExactScalarCount
            : Self.minimumExactScalarCount
        let minimumShingles =
            isPredominantlyCJK
            ? Self.minimumCJKExactUniqueShingleCount
            : Self.minimumExactUniqueShingleCount
        return scalars.count >= minimumScalars && shingles.count >= minimumShingles
    }

    func isHighOverlap(with previous: Fingerprint) -> Bool {
        guard scalars.count >= Self.minimumHighOverlapScalarCount,
            previous.scalars.count >= Self.minimumHighOverlapScalarCount,
            shingles.count >= Self.minimumHighOverlapUniqueShingleCount,
            previous.shingles.count >= Self.minimumHighOverlapUniqueShingleCount
        else { return false }

        let overlap = shingles.reduce(into: 0) { count, pair in
            count += min(pair.value, previous.shingles[pair.key, default: 0])
        }
        let candidateCoverage = Double(overlap) / Double(shingleCount)
        let previousCoverage = Double(overlap) / Double(previous.shingleCount)
        return candidateCoverage >= Self.minimumCandidateCoverage
            && previousCoverage >= Self.minimumPreviousCoverage
    }

    private static func shingles(in scalars: [UInt32]) -> [[UInt32]: Int] {
        guard scalars.count >= shingleWidth else { return [:] }
        var result: [[UInt32]: Int] = [:]
        for start in 0...(scalars.count - shingleWidth) {
            let shingle = Array(scalars[start..<(start + shingleWidth)])
            result[shingle, default: 0] += 1
        }
        return result
    }

    private var isPredominantlyCJK: Bool {
        !scalars.isEmpty && cjkScalarCount * 2 >= scalars.count
    }

    private static func isCJK(_ scalar: UInt32) -> Bool {
        switch scalar {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
            0x20000...0x2FA1F:
            true
        default:
            false
        }
    }

    private static let shingleWidth = 5
    private static let minimumExactScalarCount = 48
    private static let minimumExactUniqueShingleCount = 12
    private static let minimumCJKExactScalarCount = 32
    private static let minimumCJKExactUniqueShingleCount = 8
    private static let minimumHighOverlapScalarCount = 64
    private static let minimumHighOverlapUniqueShingleCount = 20
    private static let minimumCandidateCoverage = 0.86
    private static let minimumPreviousCoverage = 0.82
}
