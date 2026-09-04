import Foundation

/// API 请求格式枚举
/// 遵循 Codable、CaseIterable、Identifiable、Sendable。
/// 采用稳定的内部持久化标识（rawValue），配合面向 UI 的显示名称与中文说明。
public enum APIFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAIResponses = "openai_responses"
    case openAIChatCompletions = "openai_chat_completions"
    case anthropicMessages = "anthropic_messages"
    case openAICompatible = "openai_compatible"

    public var id: String { rawValue }

    /// 英文标准格式名称
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

    /// UI 清晰的中文说明
    public var descriptionText: String {
        switch self {
        case .openAIResponses:
            return "OpenAI 官方新版 Responses API 格式"
        case .openAIChatCompletions:
            return "OpenAI 标准 Chat Completions 聊天接口"
        case .anthropicMessages:
            return "Anthropic 官方 Messages 消息接口"
        case .openAICompatible:
            return "第三方或代理兼容 OpenAI 格式接口"
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
