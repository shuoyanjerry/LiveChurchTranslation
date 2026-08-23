import ASRQwen3
import Foundation
import ScriptureQualificationSupport
import TranslationHyMT2

extension ScriptureProductionQualificationRunner {
    func evaluate(
        corpus: ScriptureQualificationCorpus,
        asr: Qwen3ASRProvider,
        translator: HyMT2TranslationProvider,
        context: ScriptureQualificationRunContext
    ) async throws -> ScriptureModelQualificationReport {
        let items = Dictionary(uniqueKeysWithValues: corpus.items.map { ($0.metadata.id, $0) })
        let selectedPairs = try pairs(corpus, items: items, phase: context.phase)
        let evaluator = ScriptureQualificationPairEvaluator(asr: asr, translator: translator)
        let results = try await evaluatePairs(selectedPairs, items: items, evaluator: evaluator)
        let aggregates = results.accumulator.aggregates(partitions: [context.phase.partition])
        let gates =
            context.phase == .sealed
            ? ScriptureQualificationGatePolicy.evaluate(aggregates) : []
        let selectedItemIDs = Set(
            selectedPairs.flatMap { [$0.englishItemID, $0.simplifiedChineseItemID] }
        )
        return ScriptureModelQualificationReport(
            schemaVersion: 2,
            corpusID: corpus.manifest.corpusID,
            manifestSHA256: corpus.manifestSHA256,
            generatedAt: context.generatedAt,
            policy: .fixed(phase: context.phase),
            gatePolicyRevision: ScriptureQualificationGatePolicy.revision,
            qualified: context.phase == .sealed
                && ScriptureQualificationGatePolicy.qualifies(gates),
            providers: context.providers,
            declarations: declarationIdentities(corpus),
            items: corpus.items.filter { selectedItemIDs.contains($0.metadata.id) }
                .map(\.identityEvidence).sorted { $0.itemID < $1.itemID },
            pairs: try pairIdentities(selectedPairs, items: items),
            aggregates: aggregates,
            failures: sortedFailures(results.failures),
            gates: gates
        )
    }

    private func evaluatePairs(
        _ pairs: [ScriptureQualificationTranslationPair],
        items: [String: ScriptureQualificationVerifiedItem],
        evaluator: ScriptureQualificationPairEvaluator
    ) async throws -> ScriptureQualificationPairResults {
        var result = ScriptureQualificationPairResults()
        for pair in pairs {
            try Task.checkCancellation()
            let observations = await evaluator.evaluate(try content(for: pair, items: items))
            result.accumulator.append(contentsOf: observations)
            result.failures.append(contentsOf: failureIdentities(observations, pair: pair))
        }
        return result
    }

    private func content(
        for pair: ScriptureQualificationTranslationPair,
        items: [String: ScriptureQualificationVerifiedItem]
    ) throws -> ScriptureQualificationPairContent {
        guard let english = items[pair.englishItemID],
            let chinese = items[pair.simplifiedChineseItemID]
        else { throw ScriptureModelQualificationError.invalidCorpus }
        return ScriptureQualificationPairContent(
            englishItem: english,
            simplifiedChineseItem: chinese,
            englishReference: try ScriptureQualificationContentLoader.reference(
                at: english.referenceURL
            ),
            simplifiedChineseReference: try ScriptureQualificationContentLoader.reference(
                at: chinese.referenceURL
            )
        )
    }

    private func declarationIdentities(
        _ corpus: ScriptureQualificationCorpus
    ) -> [ScriptureDeclarationIdentity] {
        corpus.sourceDeclarations.map {
            ScriptureDeclarationIdentity(
                id: $0.metadata.id,
                editionID: $0.metadata.editionID,
                declarationSHA256: $0.metadata.declarationSHA256
            )
        }.sorted { $0.id < $1.id }
    }

    private func pairIdentities(
        _ pairs: [ScriptureQualificationTranslationPair],
        items: [String: ScriptureQualificationVerifiedItem]
    ) throws -> [ScriptureQualificationPairIdentity] {
        try pairs.map { pair in
            guard let item = items[pair.englishItemID] else {
                throw ScriptureModelQualificationError.invalidCorpus
            }
            return ScriptureQualificationPairIdentity(
                id: pair.id,
                englishItemID: pair.englishItemID,
                simplifiedChineseItemID: pair.simplifiedChineseItemID,
                partition: item.metadata.partition
            )
        }.sorted { $0.id < $1.id }
    }

    private func failureIdentities(
        _ observations: [ScriptureQualificationObservation],
        pair: ScriptureQualificationTranslationPair
    ) -> [ScriptureQualificationFailureIdentity] {
        observations.compactMap { observation in
            guard let failure = observation.failure else { return nil }
            return ScriptureQualificationFailureIdentity(
                pairID: pair.id,
                itemID: sourceItemID(for: observation.lane, pair: pair),
                lane: observation.lane,
                code: observation.diagnosticCode ?? failure.rawValue
            )
        }
    }

    private func sourceItemID(
        for lane: ScriptureQualificationLane,
        pair: ScriptureQualificationTranslationPair
    ) -> String {
        switch lane {
        case .englishASR, .englishToSimplifiedChineseCleanText,
            .englishASRToSimplifiedChinese:
            pair.englishItemID
        case .simplifiedChineseASR, .simplifiedChineseToEnglishCleanText,
            .simplifiedChineseASRToEnglish:
            pair.simplifiedChineseItemID
        }
    }

    private func sortedFailures(
        _ failures: [ScriptureQualificationFailureIdentity]
    ) -> [ScriptureQualificationFailureIdentity] {
        failures.sorted {
            ($0.pairID, $0.lane.rawValue, $0.code)
                < ($1.pairID, $1.lane.rawValue, $1.code)
        }
    }

    private func pairs(
        _ corpus: ScriptureQualificationCorpus,
        items: [String: ScriptureQualificationVerifiedItem],
        phase: ScriptureQualificationPhase
    ) throws -> [ScriptureQualificationTranslationPair] {
        try phase.select(corpus.manifest.translationPairs) { itemID in
            items[itemID]?.metadata.partition
        }
    }
}

private struct ScriptureQualificationPairResults {
    var accumulator = ScriptureQualificationAccumulator()
    var failures: [ScriptureQualificationFailureIdentity] = []
}
