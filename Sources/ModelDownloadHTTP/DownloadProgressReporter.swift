import ModelRuntimeAPI

actor DownloadProgressReporter {
    private let descriptor: ModelDescriptor
    private let reporter: any ModelRuntimeReporting
    private var lastReportedBytes: Int64 = 0
    private var isFinished = false

    init(descriptor: ModelDescriptor, reporter: any ModelRuntimeReporting) {
        self.descriptor = descriptor
        self.reporter = reporter
    }

    func begin(at completedBytes: Int64) async {
        lastReportedBytes = max(0, completedBytes)
        await publish()
    }

    func report(receivedBytes: Int64, after completedBytes: Int64) async {
        guard !isFinished else { return }
        let candidate = completedBytes + max(0, receivedBytes)
        guard candidate > lastReportedBytes else { return }
        lastReportedBytes = min(candidate, descriptor.expectedBytes)
        await publish()
    }

    func finish() {
        isFinished = true
    }

    private func publish() async {
        let total = max(1, descriptor.expectedBytes)
        let progress = min(1, Double(lastReportedBytes) / Double(total))
        await reporter.setState(.downloading(progress: progress), for: descriptor)
    }
}
