import Foundation

public enum ScriptureQualificationCorpusLoader {
    public static func load(
        manifestURL: URL,
        privateRoot: URL,
        expectedManifestSHA256: String,
        now: Date = Date()
    ) throws -> ScriptureQualificationCorpus {
        let verifier = try ScriptureQualificationFileVerifier(privateRoot: privateRoot)
        let verifiedManifestURL = try verifier.file(
            at: manifestURL,
            expectedSHA256: expectedManifestSHA256,
            label: "manifest",
            maximumBytes: Limits.manifest
        )
        let data: Data
        do {
            data = try Data(contentsOf: verifiedManifestURL, options: [.mappedIfSafe])
        } catch {
            throw ScriptureQualificationError.invalidFile("manifest is unreadable")
        }
        let manifest = try ScriptureQualificationManifestDecoder.decode(data)
        try ScriptureQualificationManifestValidator(now: now).validate(manifest)
        let grants = try verifyGrants(manifest.grants, verifier: verifier)
        let items = try verifyItems(manifest.items, verifier: verifier)
        return ScriptureQualificationCorpus(
            manifest: manifest,
            manifestSHA256: expectedManifestSHA256,
            grants: grants,
            items: items
        )
    }

    private static func verifyGrants(
        _ grants: [ScriptureQualificationGrant],
        verifier: ScriptureQualificationFileVerifier
    ) throws -> [ScriptureQualificationVerifiedGrant] {
        try grants.map { grant in
            let url = try verifier.file(
                relativePath: grant.evidencePath,
                expectedSHA256: grant.evidenceSHA256,
                label: "grant evidence \(grant.id)",
                maximumBytes: Limits.evidence
            )
            return ScriptureQualificationVerifiedGrant(metadata: grant, evidenceURL: url)
        }
    }

    private static func verifyItems(
        _ items: [ScriptureQualificationItem],
        verifier: ScriptureQualificationFileVerifier
    ) throws -> [ScriptureQualificationVerifiedItem] {
        try items.map { item in
            let audio = try verifier.file(
                relativePath: item.audioPath,
                expectedSHA256: item.audioSHA256,
                label: "audio \(item.id)",
                maximumBytes: Limits.audio
            )
            let reference = try verifier.file(
                relativePath: item.referencePath,
                expectedSHA256: item.referenceSHA256,
                label: "reference \(item.id)",
                maximumBytes: Limits.reference
            )
            return ScriptureQualificationVerifiedItem(
                metadata: item,
                audioURL: audio,
                referenceURL: reference
            )
        }
    }
}

private enum Limits {
    static let manifest = 1_048_576
    static let evidence = 16_777_216
    static let reference = 16_777_216
    static let audio = 8_589_934_592
}
