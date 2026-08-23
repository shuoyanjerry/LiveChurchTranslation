import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
func expectRetryableWithoutLeak(
    _ harness: TranslationHarness,
    forbidden: [String],
    request: TranslationRequest = TranslationRequest(
        sourceText: "恩典够用。",
        glossary: []
    )
) async {
    do {
        _ = try await harness.provider.translate(request)
        Issue.record("Expected unsafe output rejection")
    } catch let error as HyMT2Error {
        guard case .invalidOutput = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
        #expect(error.translationFailureImpact == .retryableUtterance)
        for value in forbidden {
            #expect(!error.localizedDescription.contains(value))
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
    #expect(await harness.transport.completionRequests().count == 2)
}
