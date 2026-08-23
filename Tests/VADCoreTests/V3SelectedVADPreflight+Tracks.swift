import Foundation

extension V3SelectedVADPreflight {
    func prepareTracks(
        _ items: [V3SelectedVADManifestItem],
        inputs: V3SelectedVADInputs
    ) throws -> [V3SelectedVADPreparedTrack] {
        var prepared: [V3SelectedVADPreparedTrack] = []
        for (itemIndex, item) in items.enumerated() {
            for track in item.tracks {
                let url = try validatedTrackURL(track.relativeWAVPath, inputs: inputs)
                let fingerprint = try V3SelectedVADHashing.fingerprint(url)
                guard fingerprint.sha256 == track.convertedWAVSHA256,
                    fingerprint.byteCount == track.convertedWAVByteSize,
                    try permissions(url) == 0o600
                else { throw V3SelectedVADError.provenanceMismatch("WAV identity") }
                prepared.append(
                    V3SelectedVADPreparedTrack(
                        logicalItemOrdinal: itemIndex + 1,
                        trackOrdinal: track.ordinal,
                        sceneClass: item.itemClass,
                        url: url,
                        expected: track,
                        fingerprint: fingerprint
                    )
                )
            }
        }
        guard prepared.count == V3SelectedVADPolicy.trackCount else {
            throw V3SelectedVADError.provenanceMismatch("WAV denominator")
        }
        return prepared
    }

    private func validatedTrackURL(
        _ relativePath: String,
        inputs: V3SelectedVADInputs
    ) throws -> URL {
        let candidate = inputs.corpusRootURL.appendingPathComponent(relativePath)
            .standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        let root = inputs.corpusRootURL.resolvingSymlinksInPath().standardizedFileURL
        guard resolved == candidate, resolved.path.hasPrefix(root.path + "/"),
            try V3SelectedVADHashing.isRegularNonSymbolicFile(resolved)
        else { throw V3SelectedVADError.unsafeInput }
        try validatePrivateParents(of: resolved, through: root)
        return resolved
    }

    private func validatePrivateParents(of file: URL, through root: URL) throws {
        var current = file.deletingLastPathComponent()
        while current.path.hasPrefix(root.path) {
            guard try permissions(current) == 0o700 else { throw V3SelectedVADError.unsafeInput }
            if current == root { return }
            current.deleteLastPathComponent()
        }
        throw V3SelectedVADError.unsafeInput
    }

    func permissions(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let value = attributes[.posixPermissions] as? NSNumber else {
            throw V3SelectedVADError.unsafeInput
        }
        return value.intValue
    }
}
