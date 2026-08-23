import Foundation

public struct ScriptureQualificationCorpus: Sendable {
    public let manifest: ScriptureQualificationManifest
    public let manifestSHA256: String
    public let grants: [ScriptureQualificationVerifiedGrant]
    public let items: [ScriptureQualificationVerifiedItem]

    public init(
        manifest: ScriptureQualificationManifest,
        manifestSHA256: String,
        grants: [ScriptureQualificationVerifiedGrant],
        items: [ScriptureQualificationVerifiedItem]
    ) {
        self.manifest = manifest
        self.manifestSHA256 = manifestSHA256
        self.grants = grants
        self.items = items
    }
}

public struct ScriptureQualificationVerifiedGrant: Sendable {
    public let metadata: ScriptureQualificationGrant
    public let evidenceURL: URL

    public init(metadata: ScriptureQualificationGrant, evidenceURL: URL) {
        self.metadata = metadata
        self.evidenceURL = evidenceURL
    }
}

public struct ScriptureQualificationVerifiedItem: Sendable {
    public let metadata: ScriptureQualificationItem
    public let audioURL: URL
    public let referenceURL: URL

    public init(metadata: ScriptureQualificationItem, audioURL: URL, referenceURL: URL) {
        self.metadata = metadata
        self.audioURL = audioURL
        self.referenceURL = referenceURL
    }

    public var identityEvidence: ScriptureSourceIdentityEvidence {
        ScriptureSourceIdentityEvidence(item: metadata)
    }
}
