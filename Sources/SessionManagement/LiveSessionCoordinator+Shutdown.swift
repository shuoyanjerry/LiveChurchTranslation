extension LiveSessionCoordinator {
    public func prepareForShutdown() async {
        isShuttingDown = true
        await stop()
    }

    public func shutdown() async {
        if let shutdownTask {
            await shutdownTask.value
            return
        }
        isShuttingDown = true
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performShutdown()
        }
        shutdownTask = task
        await task.value
    }

    private func performShutdown() async {
        await prepareForShutdown()
        await modelPreparation.shutdownModelPreparation()
        await dependencies.translator.shutdown()
        await dependencies.asr.unloadModel()
    }
}
