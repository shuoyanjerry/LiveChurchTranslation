import TranslationQualificationSupport

enum NegationPolicyV2ShadowSensitiveValues {
    static func collect(
        corpus: TranslationQualificationCorpus,
        classified: HyMTNegationClassifiedEvidence
    ) -> [String] {
        var result = manifestValues(corpus.manifest)
        for attempt in classified.attempts {
            result += [
                attempt.segmentID, attempt.sourceID, attempt.originalChinese,
                attempt.observedASRText, attempt.translationSourceText,
                attempt.hypothesisEnglish ?? "", attempt.humanReferenceEnglish,
                attempt.referenceProfileID,
            ]
            result += attempt.contextSegmentIDs
            result += attempt.glossaryTerms.flatMap {
                [$0.source, $0.preferredTarget] + $0.acceptedTargets
            }
            result += attempt.preservationChecks.flatMap {
                [$0.kind] + $0.expected + $0.observed
            }
            result += attempt.pronounResults.flatMap {
                [$0.occurrenceID, $0.actualGuidance, $0.englishToken ?? "", $0.englishClass]
            }
        }
        return result
    }

    private static func manifestValues(
        _ manifest: TranslationQualificationManifest
    ) -> [String] {
        var result = [manifest.corpusID]
        result += manifest.referenceProfiles.flatMap {
            [$0.id, $0.spokenTextClass, $0.translationClass] + $0.knownLimitations
        }
        result += manifest.sources.flatMap {
            [
                $0.id, $0.provider, $0.titleChinese, $0.titleEnglish, $0.speaker,
                $0.sourcePageURL, $0.referenceURL, $0.audioURL, $0.audioLocalPath,
                $0.referenceLocalPath, $0.extractedTextLocalPath, $0.referenceProfileID,
            ]
        }
        result += manifest.candidateSources.flatMap {
            [$0.id, $0.provider] + ($0.localFiles ?? []).map(\.path)
        }
        result += manifest.segments.flatMap { segment in
            var values = [
                segment.id, segment.sourceID, segment.unitKind, segment.referenceProfileID,
                segment.originalChinese, segment.observedASRAmbiguousChinese,
                segment.referenceEnglish,
            ]
            values +=
                segment.discourseContextIDs + segment.theologyTerms
                + segment.referenceWarnings
            values += segment.pronounOccurrences.flatMap {
                [
                    $0.id, $0.originalGlyph, $0.observedGlyph, $0.antecedentLabel ?? "",
                    $0.evidenceScope, $0.expectedEnglishStrategy, $0.rationaleCode,
                ]
            }
            return values
        }
        return result
    }
}
