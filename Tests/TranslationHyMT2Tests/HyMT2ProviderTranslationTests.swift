import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2ProviderTranslationTests {
    @Test func translatesWithOnlyApplicableGlossaryTerms() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("We receive justification by faith through grace.")
        ])
        defer { harness.model.remove() }
        let request = TranslationRequest(
            sourceText: "我们因信称义，这是恩典。",
            glossary: [
                TranslationTerm(source: "因信称义", target: "justification by faith"),
                TranslationTerm(source: "恩典", target: "grace"),
                TranslationTerm(source: "洗礼", target: "baptism"),
            ]
        )

        let result = try await harness.provider.translate(request)

        #expect(
            result.targetText
                == "We receive justification by faith through grace."
        )
        #expect(result.sourceText == request.sourceText)
        let prompts = await harness.transport.completionRequests().map(\.prompt)
        #expect(prompts.count == 1)
        #expect(prompts[0].contains("因信称义 translates to justification by faith"))
        #expect(!prompts[0].contains("洗礼"))
    }

    @Test func validationFailureGetsExactlyOneStrictRetry() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("We are made right."),
            .success("We receive justification by faith through grace."),
        ])
        defer { harness.model.remove() }
        let request = TranslationRequest(
            sourceText: "我们因信称义，这是恩典。",
            glossary: [
                TranslationTerm(source: "因信称义", target: "justification by faith"),
                TranslationTerm(source: "恩典", target: "grace"),
            ]
        )

        let result = try await harness.provider.translate(request)

        #expect(result.targetText.contains("justification by faith"))
        let prompts = await harness.transport.completionRequests().map(\.prompt)
        #expect(prompts.count == 2)
        #expect(!prompts[0].contains("without summarizing"))
        #expect(prompts[1].contains("without summarizing"))
    }

    @Test func secondInvalidOutputIsSurfacedWithoutThirdAttempt() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("We are made right."),
            .success("Here is the translation: We are made right."),
            .success("This response must never be consumed."),
        ])
        defer { harness.model.remove() }
        let request = TranslationRequest(
            sourceText: "我们因信称义。",
            glossary: [
                TranslationTerm(source: "因信称义", target: "justification by faith")
            ]
        )

        do {
            _ = try await harness.provider.translate(request)
            Issue.record("Expected output rejection")
        } catch let error as HyMT2Error {
            guard case .invalidOutput(let reasons) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(reasons.contains(where: { $0.contains("required term") }))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let requestCount = await harness.transport.completionRequests().count
        #expect(requestCount == 2)
    }

    @Test func transportFailureDoesNotTriggerContentRetry() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .failure(.transportFailure("connection reset")),
            .success("Unused response"),
        ])
        defer { harness.model.remove() }
        let request = TranslationRequest(sourceText: "恩典", glossary: [])

        do {
            _ = try await harness.provider.translate(request)
            Issue.record("Expected transport failure")
        } catch let error as HyMT2Error {
            #expect(error == .transportFailure("connection reset"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let requestCount = await harness.transport.completionRequests().count
        #expect(requestCount == 1)
    }

    @Test func rejectsEmptySourceWithoutCallingRuntime() async throws {
        let harness = try await makeTranslationHarness(responses: [])
        defer { harness.model.remove() }

        do {
            _ = try await harness.provider.translate(
                TranslationRequest(sourceText: "  \n", glossary: [])
            )
            Issue.record("Expected empty source error")
        } catch let error as TranslationProviderError {
            guard case .emptySource = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let requests = await harness.transport.completionRequests()
        #expect(requests.isEmpty)
    }

}
