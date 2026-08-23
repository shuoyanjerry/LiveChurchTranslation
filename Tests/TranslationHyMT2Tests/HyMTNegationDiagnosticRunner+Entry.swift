import Foundation
import TranslationQualificationSupport

extension HyMTNegationDiagnosticRunner {
    func diagnose(
        segment: TranslationQualificationSegment,
        attempt: TranslationQualificationAttempt,
        recent: [HyMTQualificationPersistedTurn]
    ) async throws -> HyMTNegationDiagnosticSegmentResult {
        let request = try HyMTNegationDiagnosticRequestFactory.make(
            segment: segment,
            classifiedAttempt: attempt,
            recent: recent
        )
        await transport.reset()
        let clock = ContinuousClock()
        let started = clock.now
        let terminalError: (any Error)?
        do {
            _ = try await provider.translate(request)
            terminalError = nil
        } catch {
            terminalError = error
        }
        let totalLatency = seconds(started.duration(to: clock.now))
        let observations = await transport.takeObservations()
        let summary = await recorder.takeSummary(for: request.id)
        let analyzed = try HyMTNegationAttemptAnalyzer.analyze(
            observations: observations,
            summary: summary,
            request: request,
            configuration: providerConfiguration
        )
        return HyMTNegationDiagnosticSegmentResult(
            entry: try entry(
                segment: segment,
                classifiedAttempt: attempt,
                observations: analyzed,
                totalLatency: totalLatency,
                terminalError: terminalError
            ),
            protectedModelOutputs: observations.compactMap(\.output)
        )
    }

    func entry(
        segment: TranslationQualificationSegment,
        classifiedAttempt: TranslationQualificationAttempt,
        observations: [HyMTNegationDiagnosticAttempt],
        totalLatency: Double,
        terminalError: (any Error)?
    ) throws -> HyMTNegationDiagnosticEntry {
        guard let failureCode = classifiedAttempt.failureCode else {
            throw TranslationQualificationError.invalidReport(
                "selected classified attempt lacks a failure code"
            )
        }
        return HyMTNegationDiagnosticEntry(
            segmentID: segment.id,
            sourceID: segment.sourceID,
            sequence: segment.sequence,
            classifiedFailureCode: failureCode,
            sourceCueClasses: HyMTNegationCueClassifier.sourceClasses(
                classifiedAttempt.translationSourceText
            ),
            referenceCueClass: HyMTNegationCueClassifier.targetClass(segment.referenceEnglish),
            attemptCount: observations.count,
            totalLatencySeconds: totalLatency,
            terminalFailureCode: terminalError.map(HyMTQualificationFailureCode.make) ?? "none",
            attempts: observations
        )
    }

    func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
