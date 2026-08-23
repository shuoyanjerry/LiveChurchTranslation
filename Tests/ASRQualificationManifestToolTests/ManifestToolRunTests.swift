import Foundation
import Testing

@Suite struct ASRQualificationManifestToolRunTests {
    @Test func freezeConfiguredManifestV2() throws {
        guard
            let inputs = try ManifestToolEnvironment.inputs(
                from: ProcessInfo.processInfo.environment
            )
        else {
            return
        }
        let result = try ASRQualificationManifestTool().run(inputs)

        #expect(result.corpusID == "public-domain-mandarin-scripture-v1")
        #expect(result.clipCount == 6)
        #expect(result.segmentCount == 220)
    }
}
