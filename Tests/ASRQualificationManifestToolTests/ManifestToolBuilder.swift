import ASRQualificationSupport

struct ManifestToolBuild {
    let manifest: ASRQualificationManifestV2
    let fileNamesByClipID: [String: String]
    let byteCountsByClipID: [String: Int64]
}

struct ManifestToolBuilder {
    let expectedSegmentCount: Int

    init(expectedSegmentCount: Int = 220) {
        self.expectedSegmentCount = expectedSegmentCount
    }

    func make(documents: ManifestToolDocuments) throws -> ManifestToolBuild {
        let strategy = try selectedStrategy(documents.vad)
        let (corpusClips, referenceClips) = try ManifestToolConsistency.validateSources(
            corpus: documents.corpus,
            reference: documents.reference
        )
        let files = try indexedFiles(strategy.files)
        guard Set(files.keys) == Set(corpusClips.keys) else {
            throw ManifestToolError.clipSetMismatch(source: "vad")
        }
        let clips = try makeClips(
            strategy: strategy,
            corpusClips: corpusClips,
            referenceClips: referenceClips
        )
        try validateCounts(strategy: strategy, clips: clips)
        let provenance = try makeProvenance(documents: documents, strategy: strategy)
        let manifest = try ASRQualificationManifestFactory.make(
            corpusID: documents.corpus.corpusID,
            provenance: provenance,
            clips: clips
        )
        return ManifestToolBuild(
            manifest: manifest,
            fileNamesByClipID: files.mapValues(\.fileName),
            byteCountsByClipID: files.mapValues(\.byteCount)
        )
    }

    private func indexedFiles(_ files: [VADFile]) throws -> [String: VADFile] {
        _ = try ManifestToolConsistency.index(
            files,
            source: "vad.corpusIDs"
        ) { $0.corpusID }
        return try ManifestToolConsistency.index(files, source: "vad.files") {
            try ManifestToolConsistency.clipID(fileName: $0.fileName)
        }
    }

    private func makeClips(
        strategy: VADStrategy,
        corpusClips: [String: CorpusClip],
        referenceClips: [String: ReferenceClip]
    ) throws -> [ASRQualificationClipV2] {
        try strategy.files.map { file in
            let id = try ManifestToolConsistency.clipID(fileName: file.fileName)
            guard let corpusClip = corpusClips[id], let referenceClip = referenceClips[id] else {
                throw ManifestToolError.clipSetMismatch(source: "vad")
            }
            return try makeClip(
                file: file,
                corpusClip: corpusClip,
                referenceClip: referenceClip,
                requiredSampleRate: strategy.configuration.policy.requiredSampleRateHz
            )
        }
    }

    private func selectedStrategy(_ report: VADReport) throws -> VADStrategy {
        let matches = report.strategies.filter { $0.strategy == "webrtcStable" }
        guard matches.count == 1, let strategy = matches.first else {
            throw ManifestToolError.strategyCount(matches.count)
        }
        return strategy
    }

    private func validateCounts(
        strategy: VADStrategy,
        clips: [ASRQualificationClipV2]
    ) throws {
        let actual = clips.reduce(0) { $0 + $1.segments.count }
        guard strategy.aggregate.segmentCount == actual else {
            throw ManifestToolError.invalidValue(path: "vad.aggregate.segmentCount")
        }
        guard actual == expectedSegmentCount else {
            throw ManifestToolError.segmentCount(expected: expectedSegmentCount, actual: actual)
        }
    }

    private func makeProvenance(
        documents: ManifestToolDocuments,
        strategy: VADStrategy
    ) throws -> ASRQualificationProvenanceV2 {
        let environment = documents.vad.environment
        guard !environment.repositoryRevision.allSatisfy(\.isWhitespace) else {
            throw ManifestToolError.invalidValue(path: "vad.environment.repositoryRevision")
        }
        let dirty = environment.repositoryHasUncommittedChanges ? "+dirty" : ""
        return ASRQualificationProvenanceV2(
            sourceVADReportSHA256: ManifestToolHashing.sha256(documents.vadData),
            sourceVADStrategy: strategy.strategy,
            sourceVADConfigurationSHA256: try ManifestToolHashing.configuration(
                strategy.configuration
            ),
            sourceReferenceManifestSHA256: ManifestToolHashing.sha256(documents.referenceData),
            sourceCorpusManifestSHA256: ManifestToolHashing.sha256(documents.corpusData),
            generatorRevision: environment.repositoryRevision + dirty
        )
    }
}
