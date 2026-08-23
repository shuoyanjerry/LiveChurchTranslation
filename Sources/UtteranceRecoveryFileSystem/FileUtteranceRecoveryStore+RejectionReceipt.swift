import Foundation
import UtteranceRecoveryAPI

extension FileUtteranceRecoveryStore {
    func validate(_ receipts: [UtteranceRejectionReceipt]) throws {
        guard !receipts.isEmpty else {
            throw UtteranceRecoveryError.invalidConfiguration("terminalRejectionReceipts")
        }
        for receipt in receipts {
            guard isValid(receipt) else {
                throw UtteranceRecoveryError.invalidConfiguration("terminalRejectionReceipt")
            }
        }
    }

    private func isValid(_ receipt: UtteranceRejectionReceipt) -> Bool {
        let code = receipt.failureCode
        return receipt.sentenceOrdinal >= 0
            && !code.isEmpty
            && code.utf8.count <= 128
            && code.unicodeScalars.allSatisfy(isAllowedFailureCodeScalar)
    }

    private func isAllowedFailureCodeScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 45, 46, 48...57, 65...90, 95, 97...122: return true
        default: return false
        }
    }

    func persist(
        _ rejection: TerminalUtteranceRejectionRecord,
        in record: URL
    ) throws {
        let url = layout.rejectionReceiptURL(in: record)
        let encoded = try encode(rejection)
        guard fileManager.fileExists(atPath: url.path) else {
            try writer.write(encoded, to: url)
            return
        }
        let existing = try decodeRejection(at: url)
        guard existing.id == rejection.id, existing.receipts == rejection.receipts else {
            throw UtteranceRecoveryError.duplicate(rejection.id)
        }
    }

    private func encode(_ record: TerminalUtteranceRejectionRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(record)
        guard data.count <= limits.maximumMetadataBytes else {
            throw UtteranceRecoveryError.invalidConfiguration("terminalRejectionReceiptSize")
        }
        return data
    }
}
