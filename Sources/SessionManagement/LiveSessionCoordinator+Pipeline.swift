import AudioCaptureAPI
import Foundation
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

extension LiveSessionCoordinator {
    func consume(
        _ stream: AsyncThrowingStream<AudioFrame, any Error>,
        sessionID: UUID
    ) async {
        do {
            for try await frame in stream {
                guard acceptsFrames(for: sessionID) else { break }
                let events = try await process(frame)
                guard acceptsFrames(for: sessionID) else { break }
                for event in events {
                    await handle(event, sessionID: sessionID)
                }
            }
            captureDidEnd(sessionID: sessionID, failure: nil)
        } catch is CancellationError {
            captureDidEnd(sessionID: sessionID, failure: nil)
        } catch {
            captureDidEnd(sessionID: sessionID, failure: error.localizedDescription)
        }
    }

    private func process(_ frame: AudioFrame) async throws -> [VoiceActivityEvent] {
        let processed = try await dependencies.audioProcessor.process(frame)
        return try await dependencies.vad.process(processed)
    }

    func handle(_ event: VoiceActivityEvent, sessionID: UUID) async {
        guard state.sessionID == sessionID else { return }
        switch event {
        case .speechStarted:
            if isActive {
                state.transition(to: .listening, message: "Speech detected")
                publishState()
            }
        case .speechEnded(let segment):
            do {
                let record = try await dependencies.recoveryStore.stage(segment, for: sessionID)
                segmentQueue.append(record)
                startWorkerIfNeeded(sessionID: sessionID)
            } catch {
                preserve(
                    segment,
                    after: UtteranceProcessingFailure(
                        stage: .persistence,
                        message: error.localizedDescription,
                        pendingEntry: nil
                    )
                )
            }
        }
    }

    private func startWorkerIfNeeded(sessionID: UUID) {
        guard workerTask == nil else { return }
        workerTask = Task { [weak self] in
            await self?.drainSegments(sessionID: sessionID)
        }
    }

    private func drainSegments(sessionID: UUID) async {
        while !segmentQueue.isEmpty {
            let record = segmentQueue.removeFirst()
            await processQueuedRecord(record, sessionID: sessionID)
            if isActive {
                state.transition(to: .listening, message: "Listening")
                publishState()
            }
        }
        workerTask = nil
    }

    private func processQueuedRecord(
        _ record: PendingUtteranceRecord,
        sessionID: UUID
    ) async {
        let segment = record.segment
        transitionWhileActive(to: .recognizing, message: "Recognizing Mandarin…")
        do {
            let entry = try await translate(segment, sessionID: sessionID)
            try await completeRecovery(record, translatedEntry: entry)
        } catch let failure as UtteranceProcessingFailure {
            preserve(segment, after: failure, recoveryID: record.id)
        } catch {
            preserve(
                segment,
                after: UtteranceProcessingFailure(
                    stage: .recognition,
                    message: error.localizedDescription,
                    pendingEntry: nil
                ),
                recoveryID: record.id
            )
        }
    }

    private func completeRecovery(
        _ record: PendingUtteranceRecord,
        translatedEntry: TranscriptEntry
    ) async throws {
        do {
            try await dependencies.recoveryStore.markCompleted(record.id)
        } catch {
            throw UtteranceProcessingFailure(
                stage: .persistence,
                message: error.localizedDescription,
                pendingEntry: translatedEntry
            )
        }
    }

    private func translate(
        _ segment: SpeechSegment,
        sessionID: UUID
    ) async throws -> TranscriptEntry {
        let recognized = try await utteranceProcessor.recognize(segment)
        transitionWhileActive(to: .translating, message: "Translating faithfully…")
        let entry = try await utteranceProcessor.translate(
            recognized,
            sessionID: sessionID
        )
        state.append(entry)
        publish(.transcriptAppended(entry))
        return entry
    }

    private func preserve(
        _ segment: SpeechSegment,
        after failure: UtteranceProcessingFailure,
        recoveryID: PendingUtteranceID? = nil
    ) {
        let issue = LiveSessionIssue(
            stage: failure.stage,
            utteranceSequence: segment.sequenceNumber,
            message: failure.message,
            isRecoverable: true
        )
        pendingUtterances.append(
            PendingUtterance(
                segment: segment,
                issue: issue,
                translatedEntry: failure.pendingEntry,
                recoveryID: recoveryID
            )
        )
        state.record(issue)
        publishState()
        publish(.recoverableError(issue.message))
        sessionFinalizer.logRecoverable(failure)
    }

    private func transitionWhileActive(to phase: LiveSessionPhase, message: String) {
        guard isActive else { return }
        state.transition(to: phase, message: message)
        publishState()
    }

    private func captureDidEnd(sessionID: UUID, failure: String?) {
        guard state.sessionID == sessionID else { return }
        Task { [weak self] in
            await self?.finishAfterCaptureEnded(sessionID: sessionID, failure: failure)
        }
    }
}
