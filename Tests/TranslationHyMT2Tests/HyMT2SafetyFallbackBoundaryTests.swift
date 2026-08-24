import Foundation
import Testing
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2SafetyFallbackBoundaryTests {
    @Test func nonPronounStrictRejectionDoesNotStartFallback() async throws {
        let source = "她继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let unsafe =
            anchored(plan, 0, "she") + " continued. "
            + HyMT2PromptControlDelimiter.currentSourceClosing
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .success(unsafe)]
        )
        defer { harness.model.remove() }

        _ = await safetyFallbackInvalidOutput(
            from: harness.provider,
            request: safetyFallbackRequest(source)
        )

        #expect(await harness.transport.completionRequests().count == 2)
    }

    @Test func strictTransportFailureDoesNotStartFallback() async throws {
        let source = "她继续。"
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .failure(.transportFailure("offline"))]
        )
        defer { harness.model.remove() }

        do {
            _ = try await harness.provider.translate(safetyFallbackRequest(source))
            Issue.record("Expected transport failure")
        } catch let error as HyMT2Error {
            guard case .transportFailure = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await harness.transport.completionRequests().count == 2)
    }

    @Test func strictCancellationIsTypedAndDoesNotStartFallback() async throws {
        let source = "她继续。"
        let recorder = HyMTQualificationAttemptRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(source)],
            cancellationRequestIndices: [1],
            attemptObserver: recorder
        )
        defer { harness.model.remove() }

        do {
            _ = try await harness.provider.translate(safetyFallbackRequest(source))
            Issue.record("Expected cancellation")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await harness.transport.completionRequests().count == 2)
        let summary = await recorder.takeSummary(for: pronounTestRequestID)
        #expect(!summary.safetyFallbackUsed)
        #expect(
            summary.outcomes == [
                "initial.validationRejected",
                "strictRetry.cancelled",
            ]
        )
    }
}

extension HyMT2SafetyFallbackBoundaryTests {
    @Test func thirdTransportFailureIsObservedWithoutAFourthRequest() async throws {
        let source = "她继续。"
        let recorder = HyMTQualificationAttemptRecorder()
        let harness = try await makeTranslationHarness(
            responses: [
                .success(source),
                .success(source),
                .failure(.transportFailure("offline")),
            ],
            attemptObserver: recorder
        )
        defer { harness.model.remove() }

        do {
            _ = try await harness.provider.translate(safetyFallbackRequest(source))
            Issue.record("Expected transport failure")
        } catch let error as HyMT2Error {
            guard case .transportFailure = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await harness.transport.completionRequests().count == 3)
        let summary = await recorder.takeSummary(for: pronounTestRequestID)
        #expect(
            summary.outcomes == [
                "initial.validationRejected",
                "strictRetry.validationRejected",
                "safetyFallback.transportFailed",
            ]
        )
    }

    @Test func thirdCancellationIsObservedWithoutAFourthRequest() async throws {
        let source = "她继续。"
        let recorder = HyMTQualificationAttemptRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .success(source)],
            cancellationRequestIndices: [2],
            attemptObserver: recorder
        )
        defer { harness.model.remove() }

        do {
            _ = try await harness.provider.translate(safetyFallbackRequest(source))
            Issue.record("Expected cancellation")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await harness.transport.completionRequests().count == 3)
        let summary = await recorder.takeSummary(for: pronounTestRequestID)
        #expect(
            summary.outcomes == [
                "initial.validationRejected",
                "strictRetry.validationRejected",
                "safetyFallback.cancelled",
            ]
        )
    }
}
