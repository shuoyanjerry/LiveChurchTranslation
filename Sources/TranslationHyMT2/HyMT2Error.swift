import Foundation
import TranslationAPI

public enum HyMT2Error: LocalizedError, Equatable, TranslationFailureImpactProviding, Sendable {
    case helperUnavailable(String)
    case modelUnavailable(String)
    case launchFailed(String)
    case startupTimedOut(String)
    case serverTerminated
    case modelNotLoaded
    case transportFailure(String)
    case malformedResponse
    case invalidInput
    case invalidOutput([String])

    public var errorDescription: String? {
        switch self {
        case .helperUnavailable(let path):
            "找不到随应用提供的 llama-server 辅助程序：\(path)。"
        case .modelUnavailable(let path):
            "找不到 Hy-MT2 GGUF 模型：\(path)。"
        case .launchFailed(let message):
            "无法启动本地翻译服务：\(message)"
        case .startupTimedOut(let message):
            "本地翻译服务未能及时就绪：\(message)"
        case .serverTerminated:
            "本地翻译服务意外停止。"
        case .modelNotLoaded:
            "尚未加载 Hy-MT2 模型。"
        case .transportFailure(let message):
            "本地翻译请求失败：\(message)"
        case .malformedResponse:
            "本地翻译服务返回了格式错误的响应。"
        case .invalidInput:
            "翻译原文含有保留的提示控制文本，已拒绝该片段。"
        case .invalidOutput(let reasons):
            "翻译模型没有返回可安全显示的译文：\(reasons.joined(separator: "；"))。原文已保留等待重译。"
        }
    }

    public var translationFailureImpact: TranslationFailureImpact {
        switch self {
        case .invalidInput:
            .terminalUtterance
        case .invalidOutput:
            .retryableUtterance
        case .helperUnavailable, .modelUnavailable, .launchFailed, .startupTimedOut,
            .serverTerminated, .modelNotLoaded, .transportFailure, .malformedResponse:
            .runtime
        }
    }

    public var translationFailureCode: String {
        switch self {
        case .helperUnavailable: "hymt2.helper_unavailable"
        case .modelUnavailable: "hymt2.model_unavailable"
        case .launchFailed: "hymt2.launch_failed"
        case .startupTimedOut: "hymt2.startup_timed_out"
        case .serverTerminated: "hymt2.server_terminated"
        case .modelNotLoaded: "hymt2.model_not_loaded"
        case .transportFailure: "hymt2.transport_failure"
        case .malformedResponse: "hymt2.malformed_response"
        case .invalidInput: "hymt2.invalid_input"
        case .invalidOutput: "hymt2.invalid_output"
        }
    }
}
