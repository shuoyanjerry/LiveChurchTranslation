import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HyMTQualificationTheologyCatalogTests {
    @Test func coversEveryFrozenManifestLabelWithAnExactRequiredEntry() throws {
        let expectedLabels = [
            "救恩", "恩典", "称义", "稱義", "因信称义", "成圣", "成聖", "重生", "赎罪", "贖罪",
            "救赎", "救贖", "三位一体", "三位一體", "圣灵", "聖靈", "团契", "團契", "事奉", "侍奉",
            "圣餐", "聖餐", "洗礼", "洗禮", "福音", "基督", "十字架", "永生", "悔改", "罪",
        ]
        let entries = HyMTQualificationTheologyCatalog.entries

        #expect(entries.count == 30)
        #expect(Set(entries.map(\.label)).count == 30)
        #expect(Set(entries.map(\.label)) == Set(expectedLabels))
        for label in expectedLabels {
            let source = "合成术语覆盖：\(label)。"
            let evidence = try HyMTQualificationGlossary.evidenceExpectations(
                source: source,
                matchedTerms: HyMTQualificationGlossary.matchedTerms(in: source),
                manifestTerms: [label],
                limit: 64
            )
            let exact = try HyMTQualificationTheologyCatalog.expectation(forExactLabel: label)
            let preservation = TranslationPreservationEvaluator.evaluate(
                segment: try syntheticTheologySegment(source: source, label: label),
                hypothesis: exact.preferredTarget,
                terms: [exact]
            )

            #expect(exact.source == label)
            #expect(exact.required)
            #expect(evidence.filter { $0.source == label } == [exact])
            #expect(preservation.terms.first?.status == .pass)
        }

        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTQualificationTheologyCatalog.expectation(forExactLabel: "恩")
        }
    }

    @Test func hashBindsEveryPolicyFieldAndAcceptedTargetOrder() {
        let entries = HyMTQualificationTheologyCatalog.entries
        let original = entries[0]
        let mutations = [
            HyMTQualificationTheologyCatalog.Entry(
                label: original.label + "变", preferredTarget: original.preferredTarget,
                acceptedTargets: original.acceptedTargets, required: original.required),
            HyMTQualificationTheologyCatalog.Entry(
                label: original.label, preferredTarget: original.preferredTarget + " changed",
                acceptedTargets: original.acceptedTargets, required: original.required),
            HyMTQualificationTheologyCatalog.Entry(
                label: original.label, preferredTarget: original.preferredTarget,
                acceptedTargets: Array(original.acceptedTargets.reversed()),
                required: original.required),
            HyMTQualificationTheologyCatalog.Entry(
                label: original.label, preferredTarget: original.preferredTarget,
                acceptedTargets: original.acceptedTargets, required: !original.required),
        ]
        let baseline = HyMTQualificationTheologyCatalog.catalogSHA256

        for mutation in mutations {
            var changed = entries
            changed[0] = mutation
            #expect(
                HyMTQualificationTheologyCatalog.catalogSHA256(
                    for: changed, policyID: HyMTQualificationTheologyCatalog.policyID) != baseline)
        }
        #expect(
            HyMTQualificationTheologyCatalog.catalogSHA256(
                for: entries, policyID: HyMTQualificationTheologyCatalog.policyID + "-changed")
                != baseline)
    }
}

private func syntheticTheologySegment(
    source: String,
    label: String
) throws -> TranslationQualificationSegment {
    let value: [String: Any] = [
        "id": "synthetic-catalog", "sourceID": "synthetic-source", "sequence": 1,
        "unitKind": "content", "referenceProfileID": "synthetic-profile",
        "discourseContextIDs": [],
        "locator": ["chinesePages": [1], "englishPages": [1]],
        "originalChinese": source, "observedASRAmbiguousChinese": source,
        "referenceEnglish": "Synthetic reference.", "featureTags": ["theologyTerm"],
        "theologyTerms": [label], "pronounOccurrences": [], "referenceWarnings": [],
        "qualification": [
            "semanticScoringEligible": true, "exactStringScoringEligible": false,
            "asrCEREligible": false, "requiresHumanSemanticReview": true,
        ],
    ]
    let data = try JSONSerialization.data(withJSONObject: value)
    return try JSONDecoder().decode(TranslationQualificationSegment.self, from: data)
}
