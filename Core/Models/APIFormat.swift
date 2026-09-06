import Foundation

/// API 请求格式枚举
/// 遵循 Codable、CaseIterable、Identifiable、Sendable。
/// 采用稳定的内部持久化标识（rawValue），配合面向 UI 的显示名称与明确的协议选择说明。
public enum APIFormat: String, CaseIterable, Identifiable, Sendable {
    case openAIResponses = "openai_responses"
    case openAIChatCompletions = "openai_chat_completions"
    case anthropicMessages = "anthropic_messages"

    // 常用格式别名
    public static let responses = APIFormat.openAIResponses
    public static let chatCompletions = APIFormat.openAIChatCompletions
    public static let anthropic = APIFormat.anthropicMessages

    public var id: String { rawValue }

    /// 界面显示的格式名称
    public var displayName: String {
        switch self {
        case .openAIResponses:
            return "Responses API"
        case .openAIChatCompletions:
            return "Chat Completions API"
        case .anthropicMessages:
            return "Anthropic API（Messages）"
        }
    }

    /// UI 说明：明确选择依据是服务商支持的接口格式
    public var descriptionText: String {
        switch self {
        case .openAIResponses:
            return "适用于支持 OpenAI 新版 Responses 协议的端点（官方或兼容中转）。"
        case .openAIChatCompletions:
            return "适用于支持标准 Chat Completions (/v1/chat/completions) 协议的官方或代理端点。"
        case .anthropicMessages:
            return "适用于支持 Anthropic Messages (/v1/messages) 协议的官方或代理端点。"
        }
    }

    /// 系统默认 API 格式
    public static let `default`: APIFormat = .openAIResponses

    /// 各格式官方默认 Base URL
    public var defaultBaseURL: String? {
        switch self {
        case .openAIResponses, .openAIChatCompletions:
            return "https://api.openai.com/v1"
        case .anthropicMessages:
            return "https://api.anthropic.com/v1"
        }
    }
}

// MARK: - Codable
extension APIFormat: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        switch rawString {
        case "openai_responses":
            self = .openAIResponses
        case "openai_chat_completions":
            self = .openAIChatCompletions
        case "anthropic_messages":
            self = .anthropicMessages
        case "openai_compatible":
            // 旧版兼容格式按已确认的规则迁移；其他配置字段与钥匙串不变。
            self = .openAIChatCompletions
        default:
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unsupported API format"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
