import Foundation
import GlossaryAPI
import TranslationAPI
import TranslationQualificationSupport
@testable import TranslationHyMT2

enum HyMTQualificationGlossary {
    static func matchedTerms(in source: String) -> [TranslationTerm] {
        DefaultGlossary.entries
            .filter(\.isEnabled)
            .filter { entry in
                ([entry.source] + entry.sourceAliases).contains {
                    source.localizedStandardContains($0)
                }
            }
            .sorted { $0.source.count > $1.source.count }
            .map { entry in
                translationTerm(entry)
            }
    }

    static func promptExpectations(
        source: String,
        matchedTerms: [TranslationTerm],
        limit: Int
    ) -> [TranslationQualificationTermExpectation] {
        TranslationTermMatcher.matched(in: source, from: matchedTerms, limit: limit).map { term in
            TranslationQualificationTermExpectation(
                source: term.source,
                preferredTarget: term.target,
                acceptedTargets: term.acceptedTargets,
                required: term.requirement == .required
            )
        }
    }

    static func evidenceExpectations(
        source: String,
        matchedTerms: [TranslationTerm],
        manifestTerms: [String],
        limit: Int
    ) throws -> [TranslationQualificationTermExpectation] {
        guard Set(manifestTerms).count == manifestTerms.count else {
            throw coverageError
        }
        var expectations = promptExpectations(
            source: source,
            matchedTerms: matchedTerms,
            limit: limit
        )
        var indices = Dictionary(
            uniqueKeysWithValues: expectations.enumerated().map { ($0.element.source, $0.offset) }
        )
        for manifestTerm in manifestTerms {
            guard source.contains(manifestTerm) else {
                throw coverageError
            }
            let expectation = try exactCatalogExpectation(for: manifestTerm)
            if let index = indices[manifestTerm] {
                expectations[index] = expectation
            } else {
                indices[manifestTerm] = expectations.count
                expectations.append(expectation)
            }
        }
        return expectations
    }

    static func requireManifestCoverage(
        _ segments: [TranslationQualificationSegment],
        limit: Int
    ) throws {
        for segment in segments {
            let source = segment.observedASRAmbiguousChinese
            _ = try evidenceExpectations(
                source: source,
                matchedTerms: matchedTerms(in: source),
                manifestTerms: segment.theologyTerms,
                limit: limit
            )
        }
    }

    static var catalogSHA256: String {
        HyMTQualificationTheologyCatalog.catalogSHA256
    }

    static var theologyPolicyID: String {
        HyMTQualificationTheologyCatalog.policyID
    }

    private static func exactCatalogExpectation(
        for source: String
    ) throws -> TranslationQualificationTermExpectation {
        try HyMTQualificationTheologyCatalog.expectation(forExactLabel: source)
    }

    private static func translationTerm(_ entry: GlossaryEntry) -> TranslationTerm {
        TranslationTerm(
            source: entry.source,
            target: entry.target,
            sourceAliases: entry.sourceAliases,
            acceptedTargets: entry.targetVariants,
            requirement: entry.enforcement == .required ? .required : .preferred
        )
    }

    private static let coverageError = TranslationQualificationError.invalidManifest(
        "manifest theology term lacks a unique exact qualification catalog entry"
    )
}
