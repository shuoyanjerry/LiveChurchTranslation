import SessionManagementAPI
import UIDesignSystem

enum LiveSessionStatusPresentation {
    static func label(for phase: LiveSessionPhase) -> String {
        switch phase {
        case .idle: "可以开始"
        case .requestingPermission, .preparingModel: "准备中"
        case .listening: "正在聆听"
        case .recognizing: "正在识别"
        case .translating: "正在翻译"
        case .stopping: "正在完成"
        case .failed: "未完成"
        }
    }

    static func indicatorStyle(for phase: LiveSessionPhase) -> StatusPillIndicatorStyle {
        switch phase {
        case .listening: .pulse
        case .requestingPermission, .preparingModel, .recognizing, .translating, .stopping:
            .progress
        case .idle, .failed: .dot
        }
    }
}
