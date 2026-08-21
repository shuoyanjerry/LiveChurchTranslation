import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI

struct ModelInstaller: Sendable {
    let rootDirectory: URL
    let transport: any ModelHTTPTransport
    let locationStore: any ModelLocationStore
    let runtimeReporter: any ModelRuntimeReporting
    private let verifier = ArtifactVerifier()

    func install(_ manifest: ModelDownloadManifest) async throws -> URL {
        let descriptor = manifest.descriptor
        let progress = DownloadProgressReporter(
            descriptor: descriptor,
            reporter: runtimeReporter
        )
        do {
            let output = try await performInstall(manifest, progress: progress)
            await progress.finish()
            try await locationStore.register(output, for: descriptor.id)
            await runtimeReporter.setState(.available(location: output), for: descriptor)
            return output
        } catch {
            await progress.finish()
            let mapped = ModelDownloadErrorNormalizer.normalize(error)
            await runtimeReporter.setState(
                .failed(message: mapped.localizedDescription),
                for: descriptor
            )
            throw mapped
        }
    }

    private func performInstall(
        _ manifest: ModelDownloadManifest,
        progress: DownloadProgressReporter
    ) async throws -> URL {
        let layout = try SecureInstallLayout(
            rootDirectory: rootDirectory,
            manifest: manifest
        )
        let inventory = try await inventory(for: manifest, layout: layout)
        guard !inventory.pending.isEmpty else { return layout.outputURL }

        await progress.begin(at: inventory.completedBytes)
        var completedBytes = inventory.completedBytes
        for pending in inventory.pending {
            try await install(pending, after: completedBytes, layout: layout, progress: progress)
            completedBytes += pending.artifact.expectedBytes
        }
        return layout.outputURL
    }

    private func inventory(
        for manifest: ModelDownloadManifest,
        layout: SecureInstallLayout
    ) async throws -> InstallInventory {
        var completedBytes: Int64 = 0
        var pending: [PendingArtifact] = []
        for artifact in manifest.artifacts {
            try Task.checkCancellation()
            let paths = try layout.prepare(for: artifact)
            if try await verifier.isValid(paths.final, artifact: artifact) {
                completedBytes += artifact.expectedBytes
            } else {
                pending.append(PendingArtifact(artifact: artifact, paths: paths))
            }
        }
        return InstallInventory(completedBytes: completedBytes, pending: pending)
    }

    private func install(
        _ pending: PendingArtifact,
        after completedBytes: Int64,
        layout: SecureInstallLayout,
        progress: DownloadProgressReporter
    ) async throws {
        try Task.checkCancellation()
        try layout.removeReplaceableItem(at: pending.paths.final)
        try layout.removeReplaceableItem(at: pending.paths.part)
        do {
            let result = try await download(pending, after: completedBytes, progress: progress)
            try validate(result, expectedBytes: pending.artifact.expectedBytes)
            guard try await verifier.isValid(pending.paths.part, artifact: pending.artifact) else {
                throw ModelDownloadError.invalidArtifact
            }
            try layout.commit(part: pending.paths.part, final: pending.paths.final)
            await progress.report(
                receivedBytes: pending.artifact.expectedBytes,
                after: completedBytes
            )
        } catch {
            try? layout.removeReplaceableItem(at: pending.paths.part)
            throw error
        }
    }

    private func download(
        _ pending: PendingArtifact,
        after completedBytes: Int64,
        progress: DownloadProgressReporter
    ) async throws -> ModelHTTPTransferResult {
        try await transport.download(
            from: pending.artifact.remoteURL,
            to: pending.paths.part
        ) { received, _ in
            Task {
                await progress.report(
                    receivedBytes: received,
                    after: completedBytes
                )
            }
        }
    }

    private func validate(
        _ result: ModelHTTPTransferResult,
        expectedBytes: Int64
    ) throws {
        guard (200...299).contains(result.statusCode) else {
            throw ModelHTTPTransportError.rejectedStatus(result.statusCode)
        }
        if let length = result.contentLength, length != expectedBytes {
            throw ModelDownloadError.invalidArtifact
        }
    }

}

private struct PendingArtifact: Sendable {
    let artifact: ModelArtifactManifest
    let paths: (final: URL, part: URL)
}

private struct InstallInventory: Sendable {
    let completedBytes: Int64
    let pending: [PendingArtifact]
}
