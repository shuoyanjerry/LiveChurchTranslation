import Foundation

enum TranscriptMigrationError: LocalizedError {
    case unsafeRoot
    case enumerationFailed
    case unsafeSessionDirectory(UUID)
    case unsafeTranscriptFile(UUID)
    case manifestIdentifierMismatch(UUID)
    case activeLegacySession(UUID)
    case legacyContentNotMigrated(UUID)

    var errorDescription: String? {
        switch self {
        case .unsafeRoot:
            "听抄稿存储目录不安全，资料迁移已停止。"
        case .enumerationFailed:
            "无法扫描听抄稿存储目录，资料迁移已停止。"
        case .unsafeSessionDirectory(let id):
            "会议 \(id.uuidString) 的资料目录不安全，迁移已停止。"
        case .unsafeTranscriptFile(let id):
            "会议 \(id.uuidString) 的听抄稿文件不安全，迁移已停止。"
        case .manifestIdentifierMismatch(let id):
            "会议 \(id.uuidString) 的资料标识不一致，迁移已停止。"
        case .activeLegacySession(let id):
            "会议 \(id.uuidString) 仍在处理中，暂不能迁移。"
        case .legacyContentNotMigrated(let id):
            "会议 \(id.uuidString) 的旧版听抄稿尚未完成迁移。"
        }
    }
}

final class TranscriptMigrationFailureCollector {
    private(set) var firstFailure: (any Error)?

    func capture(_ error: any Error) {
        if firstFailure == nil { firstFailure = error }
    }
}
