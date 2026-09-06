import Foundation

/// 终态与增量文本分开：收到部分文字不等于生成成功。
public enum StreamCompletion: Equatable, Sendable {
    case completed
    case outputLimited
    case refused
    case noText
    case incomplete
}

/// 不携带原始错误、请求地址、正文或凭据。
public enum StreamingError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case http(Int)
    case invalidContentType
    case invalidEvent
    case unexpectedEnd
    case responseTooLarge
    case generationFailed
    case timedOut
    case cancelled
    case tlsFailure
    case networkFailure

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "流式请求配置无效，未发送请求。"
        case .http(let status): return ConnectionTestError.http(status).errorDescription
        case .invalidContentType: return "服务没有返回 SSE 流，未切换协议或重试。"
        case .invalidEvent: return "流式数据格式或事件顺序无效，已停止接收。"
        case .unexpectedEnd: return "连接在收到完整结束标记前中断，已有内容可能不完整。"
        case .responseTooLarge: return "流式响应超出接收保护上限，已停止接收。"
        case .generationFailed: return "服务在流式生成期间报告错误，未自动重试。"
        case .timedOut: return "流式请求已超时，未自动重试。"
        case .cancelled: return "已取消本地请求；服务端可能仍会产生费用。"
        case .tlsFailure: return "无法建立安全连接，请检查服务端 HTTPS 证书。"
        case .networkFailure: return "流式网络请求失败，已有内容可能不完整，未自动重试。"
        }
    }

    public static func sanitized(_ error: any Error) -> StreamingError {
        if let safe = error as? StreamingError { return safe }
        if error is CancellationError { return .cancelled }
        if error is APIValidationError || error is ConnectionTestError { return .invalidRequest }
        if error is DecodingError { return .invalidEvent }
        guard let urlError = error as? URLError else { return .networkFailure }
        switch urlError.code {
        case .cancelled: return .cancelled
        case .timedOut: return .timedOut
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid,
             .clientCertificateRejected, .clientCertificateRequired: return .tlsFailure
        default: return .networkFailure
        }
    }
}

struct StreamStep: Sendable {
    var text: String = ""
    var completion: StreamCompletion?
}

/// 只接收文本；推理、工具输入和原始错误不能进入译文增量。
struct ProtocolStreamDecoder: Sendable {
    private let format: APIFormat
    private var responses = ResponsesStreamDecoder()
    private var chat = ChatStreamDecoder()
    private var messages = MessagesStreamDecoder()

    init(format: APIFormat) {
        self.format = format
    }

    mutating func consume(_ event: ServerSentEvent) throws -> StreamStep {
        switch format {
        case .openAIResponses: return try responses.consume(event)
        case .openAIChatCompletions: return try chat.consume(event)
        case .anthropicMessages: return try messages.consume(event)
        }
    }
}
