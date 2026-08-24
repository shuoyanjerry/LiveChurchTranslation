import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct SafetyFallbackCodableTests {
    @Test func historicalReportsDecodeWithoutSafetyFallbackFields() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let report = try SyntheticTranslationReportFactory.build(corpus: fixture.load())
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(report))
                as? [String: Any]
        )
        var aggregate = try #require(object["aggregate"] as? [String: Any])
        aggregate.removeValue(forKey: "safetyFallbackCount")
        object["aggregate"] = aggregate
        let attempts = try #require(object["attempts"] as? [[String: Any]])
        #expect(
            attempts.allSatisfy {
                $0["safetyFallbackUsed"] == nil && $0["backendReviewIssueCodes"] == nil
            }
        )

        let decoded = try JSONDecoder().decode(
            TranslationQualificationReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        #expect(decoded.aggregate.safetyFallbackCount == nil)
        #expect(decoded.attempts.allSatisfy { $0.safetyFallbackUsed == nil })
        #expect(decoded.attempts.allSatisfy { $0.backendReviewIssueCodes == nil })
    }
}
