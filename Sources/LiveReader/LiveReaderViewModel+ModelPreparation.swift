extension LiveReaderViewModel {
    public var displayedStatusMessage: String {
        if isRunning { return snapshot.statusMessage }
        switch modelPreparationSnapshot.phase {
        case .idle, .ready:
            return snapshot.statusMessage
        default:
            return modelPreparationSnapshot.message
        }
    }

    public var modelPreparationIsActive: Bool {
        switch modelPreparationSnapshot.phase {
        case .checking, .downloading, .loading, .retrying: true
        case .idle, .ready, .failed: false
        }
    }
}
