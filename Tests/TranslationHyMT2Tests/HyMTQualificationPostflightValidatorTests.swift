import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HyMTPostflightValidatorTests {
    @Test func attestsAReproducibleDiagnosticReportWithoutRequiringQualityPass() throws {
        let fixture = try HyMTPostflightTestFixture.make()
        #expect(
            !TranslationQualificationReleaseGate.evaluate(fixture.report).passesReleaseReadyGates
        )

        let attestation = try HyMTQualificationPostflightValidator.validate(
            snapshot: fixture.snapshot,
            corpus: fixture.corpus,
            provenance: fixture.provenance,
            configuration: fixture.configuration,
            timestamp: "2026-08-22T13:00:00Z"
        )

        #expect(attestation.reportSHA256 == fixture.snapshot.sha256)
        #expect(attestation.sourceBundleSHA256 == fixture.provenance.sourceBundle.sha256)
        #expect(attestation.testExecutableSHA256 == fixture.provenance.testExecutable.sha256)
        #expect(attestation.modelSHA256 == fixture.provenance.model.sha256)
        #expect(attestation.helperSHA256 == fixture.provenance.helper.sha256)
        #expect(attestation.runtimeBundleSHA256 == fixture.provenance.runtimeBundle.sha256)
        #expect(attestation.configurationSHA256 == fixture.provenance.configurationSHA256)
        #expect(attestation.manifestSHA256 == fixture.provenance.manifestSHA256)
        #expect(attestation.schemaSHA256 == fixture.provenance.corpusSchemaSHA256)
        #expect(attestation.postflightVerified)
    }

    @Test func rejectsSchemaV1AndReportBodyTampering() throws {
        let fixture = try HyMTPostflightTestFixture.make()
        var schemaV1 = try object(fixture.snapshot.data)
        schemaV1["schemaVersion"] = 1
        schemaV1["executionProvenance"] = nil
        #expect(throws: TranslationQualificationError.self) {
            try validate(schemaV1, fixture: fixture)
        }

        var changedAggregate = try object(fixture.snapshot.data)
        var aggregate = try #require(changedAggregate["aggregate"] as? [String: Any])
        aggregate["attemptCount"] = 7
        changedAggregate["aggregate"] = aggregate
        #expect(throws: TranslationQualificationError.self) {
            try validate(changedAggregate, fixture: fixture)
        }
    }

    @Test func rejectsExecutionProvenanceDrift() throws {
        let fixture = try HyMTPostflightTestFixture.make()
        var changed = try object(fixture.snapshot.data)
        var provenance = try #require(changed["executionProvenance"] as? [String: Any])
        provenance["configurationSHA256"] = String(repeating: "9", count: 64)
        changed["executionProvenance"] = provenance
        #expect(throws: TranslationQualificationError.self) {
            try validate(changed, fixture: fixture)
        }
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTQualificationPostflightValidator.validate(
                snapshot: HyMTQualificationReportSnapshot(
                    data: fixture.snapshot.data,
                    sha256: String(repeating: "8", count: 64)
                ),
                corpus: fixture.corpus,
                provenance: fixture.provenance,
                configuration: fixture.configuration,
                timestamp: "2026-08-22T13:00:00Z"
            )
        }
    }

    @Test func rejectsSelfConsistentProviderEnvironmentAndEncodingChanges() throws {
        let fixture = try HyMTPostflightTestFixture.make()
        var providerChange = try object(fixture.snapshot.data)
        var provider = try #require(providerChange["provider"] as? [String: Any])
        provider["identifier"] = "forged-but-self-consistent"
        providerChange["provider"] = provider
        #expect(throws: TranslationQualificationError.self) {
            try validate(providerChange, fixture: fixture)
        }

        let noncanonical = try JSONSerialization.data(
            withJSONObject: try object(fixture.snapshot.data)
        )
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTQualificationPostflightValidator.validate(
                snapshot: HyMTQualificationReportSnapshot(
                    data: noncanonical,
                    sha256: TranslationQualificationSHA256.hash(data: noncanonical)
                ),
                corpus: fixture.corpus,
                provenance: fixture.provenance,
                configuration: fixture.configuration,
                timestamp: "2026-08-22T13:00:00Z"
            )
        }
    }

    private func validate(
        _ object: [String: Any],
        fixture: HyMTPostflightTestFixture.Evidence
    ) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        _ = try HyMTQualificationPostflightValidator.validate(
            snapshot: HyMTQualificationReportSnapshot(
                data: data,
                sha256: TranslationQualificationSHA256.hash(data: data)
            ),
            corpus: fixture.corpus,
            provenance: fixture.provenance,
            configuration: fixture.configuration,
            timestamp: "2026-08-22T13:00:00Z"
        )
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
