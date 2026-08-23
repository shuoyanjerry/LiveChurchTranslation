import Foundation
import Testing
import TranslationQualificationSupport

@Suite("Negation Policy V2 private offline shadow")
struct NegationPolicyV2OfflineShadowTests {
    @Test(
        "aggregates frozen classified evidence without retaining private records",
        .enabled(
            if: NegationPolicyV2ShadowConfiguration.isRequested(
                ProcessInfo.processInfo.environment
            ),
            "Requires an explicit private offline-shadow opt in."
        )
    )
    func writesAggregateWhenExplicitlyEnabled() throws {
        guard
            let configuration = try NegationPolicyV2ShadowConfiguration.load(
                ProcessInfo.processInfo.environment
            )
        else { return }
        try execute(configuration)
    }
}
