import Foundation

/// API 请求格式枚举
/// 遵循 Codable、CaseIterable、Identifiable、Sendable。
/// 采用稳定的内部持久化标识（rawValue），配合面向 UI 的显示名称与明确的协议选择说明。
public enum APIFormat: String, CaseIterable, Identifiable, Sendable {
    case openAIResponses = "openai_responses"
    case openAIChatCompletions = "openai_chat_completions"
    case anthropicMessages = "anthropic_messages"
    case openAICompatible = "openai_compatible"

    // 常用格式别名
    public static let responses = APIFormat.openAIResponses
    public static let chatCompletions = APIFormat.openAIChatCompletions
    public static let anthropic = APIFormat.anthropicMessages
    public static let compatible = APIFormat.openAICompatible

    public var id: String { rawValue }

    /// 界面显示的格式名称
    public var displayName: String {
        switch self {
        case .openAIResponses:
            return "OpenAI Responses"
        case .openAIChatCompletions:
            return "OpenAI Chat Completions"
        case .anthropicMessages:
            return "Anthropic Messages"
        case .openAICompatible:
            return "OpenAI Compatible"
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
        case .openAICompatible:
            return "适用于各类第三方兼容 OpenAI 接口规范的模型服务，需手动填写完整 Base URL。"
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
        case .openAICompatible:
            return nil
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
            self = .openAICompatible
        default:
            self = .openAIResponses
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
