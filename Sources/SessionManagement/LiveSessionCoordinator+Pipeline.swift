import AudioCaptureAPI
import Foundation
import SessionManagementAPI
import VADAPI

extension LiveSessionCoordinator {
    func consume(
        _ stream: AsyncThrowingStream<AudioFrame, any Error>,
        sessionID: UUID
    ) async {
        do {
            for try await frame in stream {
                guard isActive else { break }
                let processed = try await dependencies.audioProcessor.process(frame)
                let events = try await dependencies.vad.process(processed)
                events.forEach { handle($0, sessionID: sessionID) }
            }
            if isActive { await stop() }
        } catch is CancellationError {
            return
        } catch {
            await failSession(error.localizedDescription)
        }
    }

    func handle(_ event: VoiceActivityEvent, sessionID: UUID) {
        switch event {
        case .speechStarted:
            state.transition(to: .listening, message: "Speech detected")
            publishState()
        case .speechEnded(let segment):
            segmentQueue.append(segment)
            startWorkerIfNeeded(sessionID: sessionID)
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
            let segment = segmentQueue.removeFirst()
            state.transition(to: .recognizing, message: "Recognizing Mandarin…")
            publishState()
            do {
                try await translate(segment, sessionID: sessionID)
            } catch {
                publish(.recoverableError(error.localizedDescription))
                sessionFinalizer.logRecoverable(error)
            }
            if isActive {
                state.transition(to: .listening, message: "Listening")
                publishState()
            }
        }
        workerTask = nil
    }

    private func translate(_ segment: SpeechSegment, sessionID: UUID) async throws {
        let recognized = try await utteranceProcessor.recognize(segment)
        state.transition(to: .translating, message: "Translating faithfully…")
        publishState()
        let entry = try await utteranceProcessor.translate(
            recognized,
            sessionID: sessionID
        )
        state.append(entry)
        publish(.transcriptAppended(entry))
    }
}
