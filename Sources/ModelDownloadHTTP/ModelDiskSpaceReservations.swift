import Foundation
import ModelDownloadAPI

actor ModelDiskSpaceReservations {
    static let productionSafetyMarginBytes: Int64 = 512 * 1_024 * 1_024

    private let rootDirectory: URL
    private let capacityProvider: any ModelDiskCapacityProviding
    private let safetyMarginBytes: Int64
    private var window: ReservationWindow?

    init(
        rootDirectory: URL,
        capacityProvider: any ModelDiskCapacityProviding,
        safetyMarginBytes: Int64
    ) throws {
        guard safetyMarginBytes >= 0 else {
            throw ModelDownloadConfigurationError.invalidDiskSafetyMargin
        }
        self.rootDirectory = rootDirectory
        self.capacityProvider = capacityProvider
        self.safetyMarginBytes = safetyMarginBytes
    }

    func reserve(additionalBytes: Int64) throws -> ModelDiskReservationToken {
        guard additionalBytes > 0 else { throw ModelDownloadError.invalidArtifact }
        let availableBytes = try availableCapacity()
        let accountedBytes = window?.accountedBytes ?? 0
        let required = Self.requiredBytes(
            accountedBytes: accountedBytes,
            additionalBytes: additionalBytes,
            safetyMarginBytes: safetyMarginBytes
        )
        guard !required.overflow, required.bytes <= availableBytes else {
            throw ModelDownloadError.insufficientDiskSpace(
                requiredBytes: required.bytes,
                availableBytes: availableBytes
            )
        }

        let token = ModelDiskReservationToken(id: UUID())
        if var activeWindow = window {
            activeWindow.accountedBytes += additionalBytes
            activeWindow.reservations[token] = Reservation(
                reservedBytes: additionalBytes,
                committedBytes: 0
            )
            window = activeWindow
        } else {
            window = ReservationWindow(
                availableBytes: availableBytes,
                accountedBytes: additionalBytes,
                reservations: [
                    token: Reservation(
                        reservedBytes: additionalBytes,
                        committedBytes: 0
                    )
                ]
            )
        }
        return token
    }

    func recordCommitted(_ bytes: Int64, for token: ModelDiskReservationToken) {
        guard bytes > 0, var activeWindow = window,
            var reservation = activeWindow.reservations[token]
        else { return }
        reservation.committedBytes = min(
            reservation.reservedBytes,
            reservation.committedBytes + bytes
        )
        activeWindow.reservations[token] = reservation
        window = activeWindow
    }

    func release(_ token: ModelDiskReservationToken) {
        guard var activeWindow = window,
            let reservation = activeWindow.reservations.removeValue(forKey: token)
        else { return }
        activeWindow.accountedBytes -= reservation.reservedBytes - reservation.committedBytes
        window = activeWindow.reservations.isEmpty ? nil : activeWindow
    }

    private func availableCapacity() throws -> Int64 {
        if let window { return window.availableBytes }
        return max(0, try capacityProvider.availableCapacity(at: rootDirectory))
    }

    private static func requiredBytes(
        accountedBytes: Int64,
        additionalBytes: Int64,
        safetyMarginBytes: Int64
    ) -> (bytes: Int64, overflow: Bool) {
        let subtotal = accountedBytes.addingReportingOverflow(additionalBytes)
        guard !subtotal.overflow else { return (.max, true) }
        let total = subtotal.partialValue.addingReportingOverflow(safetyMarginBytes)
        return total.overflow ? (.max, true) : (total.partialValue, false)
    }
}

struct ModelDiskReservationToken: Hashable, Sendable {
    let id: UUID
}

private struct ReservationWindow: Sendable {
    let availableBytes: Int64
    var accountedBytes: Int64
    var reservations: [ModelDiskReservationToken: Reservation]
}

private struct Reservation: Sendable {
    let reservedBytes: Int64
    var committedBytes: Int64
}
