import SwiftUI
@preconcurrency import Translation

@available(macOS 15.0, *)
extension View {
    public func appleTranslationRuntime(provider: AppleTranslationProvider) -> some View {
        modifier(AppleTranslationRuntimeModifier(provider: provider))
    }
}

@available(macOS 15.0, *)
private struct AppleTranslationRuntimeModifier: ViewModifier {
    let provider: AppleTranslationProvider
    @State private var configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "zh-Hans"),
        target: Locale.Language(identifier: "en")
    )

    func body(content: Content) -> some View {
        content.translationTask(configuration) { session in
            await provider.attach(session)
        }
    }
}
