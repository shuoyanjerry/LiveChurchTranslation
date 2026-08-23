import Foundation

public struct ScriptureQualificationCorpus: Sendable {
    public let manifest: ScriptureQualificationManifest
    public let manifestSHA256: String
    public let sourceDeclarations: [ScriptureVerifiedSourceDeclaration]
    public let items: [ScriptureQualificationVerifiedItem]

    public init(
        manifest: ScriptureQualificationManifest,
        manifestSHA256: String,
        sourceDeclarations: [ScriptureVerifiedSourceDeclaration],
        items: [ScriptureQualificationVerifiedItem]
    ) {
        self.manifest = manifest
        self.manifestSHA256 = manifestSHA256
        self.sourceDeclarations = sourceDeclarations
        self.items = items
    }
}

public struct ScriptureVerifiedSourceDeclaration: Sendable {
    public let metadata: ScriptureQualificationSourceDeclaration
    public let declarationURL: URL

    public init(metadata: ScriptureQualificationSourceDeclaration, declarationURL: URL) {
        self.metadata = metadata
        self.declarationURL = declarationURL
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
