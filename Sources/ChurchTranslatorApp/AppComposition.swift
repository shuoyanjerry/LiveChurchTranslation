import LiveReader
import SessionManagement

@MainActor
enum AppComposition {
    static func build() throws -> LiveReaderViewModel {
        let directories = try AppDirectories.production()
        let services = try AppServiceGraph(directories: directories)
        let controller = LiveSessionCoordinator(
            dependencies: try services.makeSessionDependencies(directories: directories),
            models: SessionModelDescriptors(
                speechRecognition: ProductionModelCatalog.qwenDescriptor,
                translation: ProductionModelCatalog.translationDescriptor
            )
        )
        return LiveReaderViewModel(
            controller: controller,
            capture: services.capture,
            glossary: services.glossary,
            settingsStore: services.settings
        )
    }
}
