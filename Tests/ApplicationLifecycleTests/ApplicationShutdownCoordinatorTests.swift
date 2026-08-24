@testable import ApplicationLifecycle
import Testing

@Suite @MainActor struct ApplicationShutdownCoordinatorTests {
    @Test func repeatedRequestsShareCleanupAndCompleteEveryRequest() async {
        let gate = CleanupGate()
        let events = ShutdownEvents()
        let coordinator = makeCoordinator(gate: gate, events: events)
        let completions = CompletionRecorder()

        coordinator.request { completions.append(1) }
        coordinator.request { completions.append(2) }
        await gate.waitUntilBlocked()

        #expect(await events.importCancellationCount() == 1)
        #expect(await events.sessionPreparationCount() == 0)
        #expect(await events.modelPreparationShutdownCount() == 0)
        #expect(await events.sessionShutdownCount() == 0)
        #expect(completions.values.isEmpty)

        await gate.release()
        await completions.waitUntilCount(2)

        #expect(completions.values == [1, 2])
        #expect(await events.importCancellationCount() == 1)
        #expect(await events.sessionPreparationCount() == 1)
        #expect(await events.modelPreparationShutdownCount() == 1)
        #expect(await events.sessionShutdownCount() == 1)
        #expect(
            await events.all()
                == [.importCancellation, .sessionPreparation, .modelPreparation, .session]
        )
    }

    @Test func terminationSignalCleansUpBeforeExit() async {
        let gate = CleanupGate()
        let events = ShutdownEvents()
        let coordinator = makeCoordinator(gate: gate, events: events)
        let completions = CompletionRecorder()

        coordinator.handleTerminationSignal {
            completions.append(1)
        }
        await gate.waitUntilBlocked()

        #expect(completions.values.isEmpty)
        #expect(await events.sessionShutdownCount() == 0)

        await gate.release()
        await completions.waitUntilCount(1)

        #expect(await events.importCancellationCount() == 1)
        #expect(await events.sessionPreparationCount() == 1)
        #expect(await events.modelPreparationShutdownCount() == 1)
        #expect(await events.sessionShutdownCount() == 1)
        #expect(completions.values == [1])
    }

    private func makeCoordinator(
        gate: CleanupGate,
        events: ShutdownEvents
    ) -> ApplicationShutdownCoordinator {
        ApplicationShutdownCoordinator(
            shutdownImport: {
                await events.recordImportCancellation()
                await gate.wait()
            },
            prepareSessionForShutdown: {
                await events.recordSessionPreparation()
                await gate.wait()
            },
            shutdownModelPreparations: {
                await events.recordModelPreparationShutdown()
                await gate.wait()
            },
            shutdownSession: {
                await events.recordSessionShutdown()
                await gate.wait()
            }
        )
    }

}
