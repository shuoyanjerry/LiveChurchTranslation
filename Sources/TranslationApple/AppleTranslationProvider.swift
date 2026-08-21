import Foundation
@preconcurrency import Translation
import TranslationAPI

@available(macOS 15.0, *)
@MainActor
public final class AppleTranslationProvider: TranslationProvider {
    public nonisolated let identifier = "apple.translation.on-device"

    private var session: TranslationSession?
    private var preparationError: Error?

    public init() {}

    public func attach(_ session: TranslationSession) async {
        self.session = session
        do {
            try await session.prepareTranslation()
            preparationError = nil
        } catch {
            preparationError = error
        }
    }

    public func loadModel(at location: URL) async throws {
        _ = location
        for _ in 0..<100 where session == nil && preparationError == nil {
            try await Task.sleep(for: .milliseconds(50))
        }
        if let preparationError {
            throw TranslationProviderError.translationFailed(preparationError.localizedDescription)
        }
        guard let session else { throw TranslationProviderError.runtimeNotAttached }
        do {
            try await session.prepareTranslation()
        } catch {
            throw TranslationProviderError.translationFailed(error.localizedDescription)
        }
    }

    public func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        guard !request.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationProviderError.emptySource
        }
        guard let session else { throw TranslationProviderError.runtimeNotAttached }
        let protected = GlossaryProtector.protect(request.sourceText, terms: request.glossary)
        let clock = ContinuousClock()
        let started = clock.now

        do {
            var response = try await session.translate(protected.source).targetText
            if let restored = GlossaryProtector.restore(response, input: protected) {
                response = restored
            } else {
                response = try await session.translate(protected.inlineFallbackSource).targetText
                guard let restored = GlossaryProtector.restore(response, input: protected) else {
                    throw TranslationProviderError.invalidOutput
                }
                response = restored
            }
            let validated = try TranslationGuard.validate(response, for: request)
            return TranslationResult(
                requestID: request.id,
                sourceText: request.sourceText,
                targetText: validated,
                duration: started.duration(to: clock.now)
            )
        } catch let error as TranslationProviderError {
            throw error
        } catch {
            throw TranslationProviderError.translationFailed(error.localizedDescription)
        }
    }

    public func shutdown() async {
        session = nil
        preparationError = nil
    }
}
