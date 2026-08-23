import SessionManagement

extension AppComposition {
    static var productionModels: SessionModelDescriptors {
        SessionModelDescriptors(
            speechRecognition: ProductionModelCatalog.qwenDescriptor,
            translation: ProductionModelCatalog.translationDescriptor
        )
    }

    @discardableResult
    static func recoverInterruptedRecordings(
        services: AppServiceGraph
    ) async -> InterruptedSessionRecoveryReport {
        await InterruptedSessionRecoveryCoordinator(
            transcripts: services.transcripts,
            recordings: services.recordings,
            recovery: services.recovery,
            diagnostics: services.diagnostics
        ).recover()
    }
}
