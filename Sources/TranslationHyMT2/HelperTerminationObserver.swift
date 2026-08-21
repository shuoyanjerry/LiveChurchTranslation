import Foundation

final class HelperTerminationObserver: @unchecked Sendable {
    private let notificationCenter: NotificationCenter
    private let token: NSObjectProtocol

    init(
        managedProcess: ManagedHelperProcess,
        notificationCenter: NotificationCenter = .default
    ) {
        self.notificationCenter = notificationCenter
        token = notificationCenter.addObserver(
            forName: Notification.Name("NSApplicationWillTerminateNotification"),
            object: nil,
            queue: nil
        ) { _ in
            managedProcess.stop()
        }
    }

    deinit {
        notificationCenter.removeObserver(token)
    }
}
