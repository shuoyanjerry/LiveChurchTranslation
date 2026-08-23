import Foundation

private struct V3SelectedVADWAVIdentity: Encodable {
    let logicalItemOrdinal: Int
    let trackOrdinal: Int
    let sha256: String
    let byteCount: Int64
    let exactSampleFrames: Int64
}

extension V3SelectedVADPreflight {
    func wavSetDigest(_ tracks: [V3SelectedVADPreparedTrack]) throws -> String {
        let identities = try tracks.map { track in
            let current = try V3SelectedVADHashing.fingerprint(track.url)
            guard current == track.fingerprint else { throw V3SelectedVADError.unsafeInput }
            return V3SelectedVADWAVIdentity(
                logicalItemOrdinal: track.logicalItemOrdinal,
                trackOrdinal: track.trackOrdinal,
                sha256: current.sha256,
                byteCount: current.byteCount,
                exactSampleFrames: track.expected.exactSampleFrames
            )
        }
        return try V3SelectedVADHashing.canonicalDigest(identities)
    }

    func conversionPolicyDigest(_ manifestData: Data) throws -> String {
        guard let document = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
            let policy = document["conversion_policy"]
        else { throw V3SelectedVADError.invalidManifest("conversion policy") }
        let data = try JSONSerialization.data(
            withJSONObject: policy,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return V3SelectedVADHashing.digest(data)
    }

    func validatePrivateDocumentPermissions(_ inputs: V3SelectedVADInputs) throws {
        let privateFiles = [
            inputs.manifestURL, inputs.validationURL,
            inputs.sourceManifestURL, inputs.builderURL,
        ]
        guard try privateFiles.allSatisfy({ try permissions($0) == 0o600 }) else {
            throw V3SelectedVADError.unsafeInput
        }
    }

    func forbiddenValues(
        manifest: V3SelectedVADManifest,
        inputs: V3SelectedVADInputs
    ) -> [String] {
        let manifestValues = manifest.items.flatMap { item in
            [item.itemID] + item.tracks.flatMap { [$0.itemID, $0.relativeWAVPath] }
        }
        return manifestValues + [
            inputs.workspaceRoot.path, inputs.manifestURL.path, inputs.validationURL.path,
            inputs.sourceManifestURL.path, inputs.builderURL.path,
        ]
    }
}
