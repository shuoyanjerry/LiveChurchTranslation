import ASRQualificationSupport
import Foundation

struct FunQualificationFixture {
    let manifest: ASRQualificationManifestV2
    let references: FunQualificationReferenceCatalog

    static func load(inputs: FunQualificationInputs) throws -> Self {
        let manifestData = try Data(
            contentsOf: inputs.manifestURL,
            options: .mappedIfSafe
        )
        let actualSHA = FunQualificationHashing.sha256(manifestData)
        guard actualSHA == FunQualificationConfiguration.frozenManifestSHA256 else {
            throw FunQualificationFixtureError.manifestSHA256Mismatch
        }
        let manifest = try ASRQualificationManifestDecoder().decode(manifestData)
        let references = try FunQualificationReferenceCatalog.load(
            from: inputs.referenceManifestURL,
            for: manifest
        )
        return Self(manifest: manifest, references: references)
    }
}

enum FunQualificationFixtureError: Error, Equatable {
    case manifestSHA256Mismatch
}
