import SessionManagement

extension AppComposition {
    static var productionModels: SessionModelDescriptors {
        SessionModelDescriptors(
            speechRecognition: ProductionModelCatalog.qwenDescriptor,
            translation: ProductionModelCatalog.translationDescriptor
        )
    }

    static func recoverInterruptedRecordings(services: AppServiceGraph) async {
        guard let sessions = try? await services.transcripts.recentSessions(limit: 10_000) else {
            return
        }
        for session in sessions {
            _ = try? await services.recordings.repairInterruptedRecording(sessionID: session.id)
        }
    }
}
