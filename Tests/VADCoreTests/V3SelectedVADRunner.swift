import Foundation

struct V3SelectedVADRunner {
    func replay(_ tracks: [V3SelectedVADPreparedTrack]) async -> [V3SelectedVADAttempt] {
        var attempts: [V3SelectedVADAttempt] = []
        for track in tracks {
            attempts.append(await replay(track))
        }
        return attempts
    }

    private func replay(_ track: V3SelectedVADPreparedTrack) async -> V3SelectedVADAttempt {
        do {
            let metrics = try await V3SelectedVADWAVReplay().run(track)
            return attempt(track, success: true, failure: nil, metrics: metrics)
        } catch V3SelectedVADError.invalidWAV {
            return attempt(track, failure: .invalidWAV)
        } catch V3SelectedVADError.incompleteRead {
            return attempt(track, failure: .incompleteRead)
        } catch V3SelectedVADError.parityMismatch {
            return attempt(track, failure: .parityMismatch)
        } catch V3SelectedVADError.unsafeInput {
            return attempt(track, failure: .sourceMutation)
        } catch {
            return attempt(track, failure: .processingFailure)
        }
    }

    private func attempt(
        _ track: V3SelectedVADPreparedTrack,
        success: Bool = false,
        failure: V3SelectedVADFailureCode?,
        metrics: V3SelectedVADTrackMetrics? = nil
    ) -> V3SelectedVADAttempt {
        V3SelectedVADAttempt(
            logicalItemOrdinal: track.logicalItemOrdinal,
            trackOrdinal: track.trackOrdinal,
            sceneClass: track.sceneClass,
            sourceWAVSHA256: track.fingerprint.sha256,
            sourceWAVByteCount: track.fingerprint.byteCount,
            exactSampleFrames: track.expected.exactSampleFrames,
            audioSeconds: Double(track.expected.exactSampleFrames) / 16_000,
            resetBeforeTrack: true,
            endOfStreamAfterTrack: true,
            success: success,
            failureCode: failure,
            metrics: metrics
        )
    }
}
