import Foundation

public enum TranslationFailure: Equatable, Sendable {
    case notConfigured
    case keychainUnavailable
    case request(StreamingError)

    public var message: String {
        switch self {
        case .notConfigured: return "请先在设置中保存 API 配置与 API Key。"
        case .keychainUnavailable: return "无法读取 API Key，请解锁设备或检查已保存的密钥。"
        case .request(let error): return error.errorDescription ?? "翻译请求失败，未自动重试。"
        }
    }
}

public enum TranslationState: Equatable, Sendable {
    case idle
    case running
    case finished(StreamCompletion)
    case failed(TranslationFailure)
    case cancelled
    case sourceChanged
    case styleChanged

    public var message: String? {
        switch self {
        case .idle: return nil
        case .running: return "正在翻译…"
        case .finished(let completion):
            switch completion {
            case .completed: return "翻译完成"
            case .outputLimited: return "已达到输出上限，译文未完整生成。可在设置中调整上限后重新翻译。"
            case .refused: return "服务拒绝了本次内容，已有译文可能不完整。"
            case .noText: return "服务已结束，但没有返回可见译文。"
            case .incomplete: return "服务未完整完成翻译，已保留收到的内容。"
            }
        case .failed(let failure): return failure.message
        case .cancelled: return "已停止，保留已有译文；服务端可能仍会产生费用。"
        case .sourceChanged: return "原文或语言已修改，当前译文仅供参考，请重新翻译。"
        case .styleChanged: return "翻译风格已修改，当前译文仍为原风格；点击翻译以应用新设置。"
        }
    }
}
