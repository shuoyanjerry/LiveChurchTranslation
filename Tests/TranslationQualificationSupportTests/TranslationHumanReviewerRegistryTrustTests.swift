import CryptoKit
import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HumanReviewerRegistryTrustTests {
    @Test func injectedSyntheticRootVerifiesButProductionFailsClosed() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let registry = try SyntheticHumanReviewerRegistryFactory.make(rootKey: rootKey)
        let data = try TranslationHumanReviewEvidence.encodeReviewerRegistry(registry)
        let policy = try SyntheticHumanReviewerRegistryFactory.policy(rootKey: rootKey)

        #expect(
            try TranslationHumanReviewEvidence.decodeUntrustedReviewerRegistry(from: data)
                == registry
        )
        #expect(
            try TranslationHumanReviewEvidence.verifyReviewerRegistry(
                from: data,
                trustPolicy: policy
            ) == registry
        )
        #expect(
            TranslationHumanReviewEvidence.productionReviewerRegistryTrustPolicy
                .rootPublicKeysByID.isEmpty
        )
        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationHumanReviewEvidence.decodeProductionReviewerRegistry(from: data)
        }
    }

    @Test func callerSuppliedPathHashAndSelfMadeRootCannotEstablishProductionTrust() throws {
        let attackerRoot = Curve25519.Signing.PrivateKey()
        let registry = try SyntheticHumanReviewerRegistryFactory.make(rootKey: attackerRoot)
        let data = try TranslationHumanReviewEvidence.encodeReviewerRegistry(registry)
        let attackerPolicy = try SyntheticHumanReviewerRegistryFactory.policy(
            rootKey: attackerRoot
        )

        #expect(
            try TranslationHumanReviewEvidence.verifyReviewerRegistry(
                from: data,
                trustPolicy: attackerPolicy
            ) == registry
        )
        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationHumanReviewEvidence.decodeProductionReviewerRegistry(from: data)
        }
    }

    @Test func signedEnvelopeMutationAndRevisionReplayFailClosed() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let registry = try SyntheticHumanReviewerRegistryFactory.make(rootKey: rootKey)
        let policy = try SyntheticHumanReviewerRegistryFactory.policy(rootKey: rootKey)
        let wrongRevision = try SyntheticHumanReviewerRegistryFactory.policy(
            rootKey: rootKey,
            registryRevision: 2
        )
        let tampered = TranslationHumanReviewerRegistry(
            policyRevision: registry.policyRevision,
            registryID: registry.registryID,
            registryRevision: registry.registryRevision,
            rootKeyID: registry.rootKeyID,
            reviewers: registry.reviewers,
            signatureBase64: Data(repeating: 0, count: 64).base64EncodedString()
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationHumanReviewEvidence.verifyReviewerRegistry(
                from: TranslationHumanReviewEvidence.encodeReviewerRegistry(tampered),
                trustPolicy: policy
            )
        }
        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationHumanReviewEvidence.verifyReviewerRegistry(
                from: TranslationHumanReviewEvidence.encodeReviewerRegistry(registry),
                trustPolicy: wrongRevision
            )
        }
    }

    @Test func legacyUnknownDuplicateAndNoncanonicalRegistryBytesAreRejected() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let registry = try SyntheticHumanReviewerRegistryFactory.make(rootKey: rootKey)
        let data = try TranslationHumanReviewEvidence.encodeReviewerRegistry(registry)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var legacy = object
        legacy["schemaVersion"] = 1
        var unknown = object
        unknown["unexpected"] = true
        let text = try #require(String(data: data, encoding: .utf8))
        let duplicate = Data(
            text.replacingOccurrences(
                of: "{",
                with: "{\"schemaVersion\":2,",
                options: [],
                range: text.startIndex..<text.index(after: text.startIndex)
            ).utf8
        )
        var noncanonical = Data(" \n".utf8)
        noncanonical.append(data)

        for invalid in [
            try JSONSerialization.data(withJSONObject: legacy, options: .sortedKeys),
            try JSONSerialization.data(withJSONObject: unknown, options: .sortedKeys),
            duplicate,
            noncanonical,
        ] {
            #expect(throws: TranslationQualificationError.self) {
                _ = try TranslationHumanReviewEvidence.decodeUntrustedReviewerRegistry(
                    from: invalid
                )
            }
        }
    }
}
