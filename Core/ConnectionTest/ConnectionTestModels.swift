import Foundation

/// 连接测试独立于正式翻译；不接收原文、历史或额外提示词。
public enum ConnectionTestPolicy {
    public static let defaultOutputLimit = 256
    public static let timeout: TimeInterval = 30
    public static let prompt = "Reply with OK."

    public static func outputLimit(from text: String) throws -> Int {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
              let number = Int(value), number > 0 else {
            throw ConnectionTestError.invalidOutputLimit
        }
        return number
    }
}

/// 只携带固定脱敏文案和 HTTP 状态，不保留服务器正文、URL 或凭据。
public enum ConnectionTestError: Error, LocalizedError, Equatable, Sendable {
    case notConfigured
    case keychainUnavailable
    case invalidAPIKey
    case invalidOutputLimit
    case invalidConfiguration(APIValidationError)
    case http(Int)
    case invalidResponse
    case responseTooLarge
    case generationFailed
    case timedOut
    case cancelled
    case offline
    case tlsFailure
    case unreachable
    case networkFailure

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "请先保存 API 配置与 API Key。"
        case .keychainUnavailable: return "无法读取已保存的 API Key，请解锁设备或重新保存密钥。"
        case .invalidAPIKey: return "API Key 格式无效，不能包含空格、控制字符或非 ASCII 字符。"
        case .invalidOutputLimit: return "请输入大于 0 的整数；数值过大时请减小。"
        case .invalidConfiguration(let error): return error.errorDescription
        case .http(let status):
            switch status {
            case 300..<400: return "服务返回重定向（HTTP \(status)）。为保护密钥未跟随跳转，请核对最终服务地址。"
            case 400, 422: return "请求参数不被接受（HTTP \(status)）。请检查协议、Model ID 和输出上限；未自动改值或重试。"
            case 401: return "认证失败（HTTP 401）。请检查 API Key 是否正确或已过期。"
            case 403: return "访问被拒绝（HTTP 403）。请检查账户、模型或服务权限。"
            case 404: return "资源不存在（HTTP 404）。请检查服务地址、接口路径与 Model ID。"
            case 408, 504: return "服务端请求超时（HTTP \(status)），未自动重试。"
            case 429: return "请求受限（HTTP 429）。可能是频率限制或额度不足，请在服务商处确认。"
            case 500..<600: return "服务端暂时异常（HTTP \(status)），未自动重试。"
            default: return "请求未成功（HTTP \(status)）。请检查服务配置。"
            }
        case .invalidResponse: return "已收到响应，但不是所选协议的有效完整响应，请检查服务地址与协议。"
        case .responseTooLarge: return "测试响应异常过大，已停止接收。请检查服务或减小输出上限。"
        case .generationFailed: return "接口已响应，但服务报告生成失败或尚未完成。未继续轮询或重试。"
        case .timedOut: return "连接测试已超时（30 秒），未自动重试。"
        case .cancelled: return "已取消本地请求；服务端可能仍会产生费用。"
        case .offline: return "网络不可用，请检查设备网络连接。"
        case .tlsFailure: return "无法建立安全连接，请检查服务端 HTTPS 证书。"
        case .unreachable: return "无法连接到服务，请检查地址、DNS 与网络。"
        case .networkFailure: return "网络请求失败，未自动重试。"
        }
    }

    public static func sanitized(_ error: any Error) -> ConnectionTestError {
        if let safe = error as? ConnectionTestError { return safe }
        if let validation = error as? APIValidationError { return .invalidConfiguration(validation) }
        if error is CancellationError { return .cancelled }
        guard let urlError = error as? URLError else { return .networkFailure }
        switch urlError.code {
        case .cancelled: return .cancelled
        case .timedOut: return .timedOut
        case .notConnectedToInternet, .dataNotAllowed: return .offline
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed: return .unreachable
        case .secureConnectionFailed, .serverCertificateHasBadDate,
             .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected,
             .clientCertificateRequired: return .tlsFailure
        default: return .networkFailure
        }
    }
}

public enum ConnectionTestOutcome: Equatable, Sendable {
    case success
    case outputLimited
    case noText
    case refused
    case incomplete

    public var title: String {
        switch self {
        case .success: return "连接成功"
        case .outputLimited: return "接口已响应，输出受限"
        case .noText: return "接口已响应，未返回文本"
        case .refused: return "接口已响应，测试内容被拒绝"
        case .incomplete: return "接口已响应，测试未完整完成"
        }
    }

    public var detail: String {
        switch self {
        case .success: return "已识别所选协议的正常文本响应。本次结果不代表翻译质量或服务持续可用。"
        case .outputLimited: return "服务报告已达到输出上限，推理也可能占用额度。可自行调整上限后再次测试。"
        case .noText: return "协议响应有效，但没有可见文本。请检查模型是否支持文本生成。"
        case .refused: return "服务拒绝了固定测试内容，未自动更换提示词或重试。"
        case .incomplete: return "服务未正常完成文本生成，未自动追加请求。"
        }
    }
}

public struct ConnectionTestResult: Equatable, Sendable {
    public let outcome: ConnectionTestOutcome
    public let elapsedSeconds: Double

    public init(outcome: ConnectionTestOutcome, elapsedSeconds: Double) {
        self.outcome = outcome
        self.elapsedSeconds = elapsedSeconds
    }
}

public enum ConnectionTestState: Equatable, Sendable {
    case idle
    case running
    case finished(ConnectionTestResult)
    case failed(ConnectionTestError)
    case cancelled
}
