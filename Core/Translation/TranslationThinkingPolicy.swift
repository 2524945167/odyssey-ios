import Foundation

/// 统一开关，只使用文档明确支持开/关的普通控制方式。
/// 同一协议下的控制参数仍因服务而异：未知端点、模型和特殊推理配置不猜测。
public enum TranslationThinkingPolicy {
    public enum Control: Equatable, Sendable {
        case chatEffort
        case responsesEffort
        case booleanThinking
        case typedThinking
        case adaptiveThinking
    }

    public static func supports(_ configuration: APIConfiguration?) -> Bool {
        control(for: configuration) != nil
    }

    public static func control(for configuration: APIConfiguration?) -> Control? {
        guard let configuration,
              let url = URLComponents(string: configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host?.lowercased(),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.port == nil || url.port == 443 else { return nil }
        var path = url.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        let model = configuration.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let format = configuration.apiFormat

        if isDashScopeHost(host) {
            if format == .openAIChatCompletions && path == "/compatible-mode/v1" && dashScopeModels.contains(model) {
                return .booleanThinking
            }
            if format == .openAIResponses &&
                ["/compatible-mode/v1", "/api/v2/apps/protocols/compatible-mode/v1"].contains(path) &&
                dashScopeResponsesModels.contains(model) { return .responsesEffort }
            return nil
        }
        if host == "api.openai.com" && path == "/v1" && openAIModels.contains(model) {
            if format == .openAIChatCompletions { return .chatEffort }
            if format == .openAIResponses { return .responsesEffort }
        }
        if host == "api.deepseek.com" && ["", "/v1"].contains(path) &&
            ["deepseek-v4-flash", "deepseek-v4-pro"].contains(model) {
            if format == .openAIChatCompletions { return .typedThinking }
            if format == .openAIResponses { return .responsesEffort }
        }
        if host == "api.anthropic.com" && path == "/v1" && format == .anthropicMessages &&
            adaptiveClaudeModels.contains(model) { return .adaptiveThinking }
        if host == "generativelanguage.googleapis.com" && path == "/v1beta/openai" &&
            format == .openAIChatCompletions && ["gemini-2.5-flash", "gemini-2.5-flash-lite"].contains(model) {
            return .chatEffort
        }
        return nil
    }

    private static func isDashScopeHost(_ host: String) -> Bool {
        if ["dashscope.aliyuncs.com", "dashscope-intl.aliyuncs.com", "cn-hongkong.dashscope.aliyuncs.com"].contains(host) { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        let regions = ["cn-beijing", "ap-southeast-1", "cn-hongkong", "us-east-1", "eu-central-1", "ap-northeast-1"]
        return parts.count == 5 && !parts[0].isEmpty &&
            parts[0].utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 } &&
            regions.contains(String(parts[1])) && parts[2] == "maas" && parts[3] == "aliyuncs" && parts[4] == "com"
    }

    // 固定的已核实标识，不使用 gpt-* / claude-* 等前缀匹配去猜测新模型能力。
    // 原始接口、路径和模型字符串从不被这些规则改写。依据见 ROUND8_1_VERIFICATION.md。
    private static let openAIModels: Set<String> = [
        "gpt-5.1", "gpt-5.1-2025-11-13", "gpt-5.2", "gpt-5.2-2025-12-11",
        "gpt-5.4", "gpt-5.5", "gpt-5.6", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"
    ]
    private static let adaptiveClaudeModels: Set<String> = [
        "claude-opus-4-6", "claude-sonnet-4-6", "claude-opus-4-7", "claude-opus-4-8", "claude-sonnet-5"
    ]
    private static let dashScopeResponsesModels: Set<String> = [
        "qwen3.8-max", "qwen3.8-flash", "qwen3.8-27b",
        "qwen3.7-max", "qwen3.7-max-2026-05-20", "qwen3.7-max-2026-06-08",
        "qwen3.7-plus", "qwen3.7-plus-2026-05-26", "qwen3.7-flash", "qwen3.7-flash-2026-07-15",
        "qwen3.6-plus", "qwen3.6-plus-2026-04-02", "qwen3.6-flash", "qwen3.6-flash-2026-04-16", "qwen3.6-35b-a3b",
        "qwen3.5-plus", "qwen3.5-plus-2026-02-15", "qwen3.5-flash", "qwen3.5-flash-2026-02-23",
        "qwen3.5-397b-a17b", "qwen3.5-122b-a10b", "qwen3.5-27b", "qwen3.5-35b-a3b",
        "qwen3-max", "qwen3-max-2026-01-23", "deepseek-v4-pro", "deepseek-v4-flash", "glm-5.2"
    ]
    private static let dashScopeModels: Set<String> = dashScopeResponsesModels.union([
        "qwen3.6-max-preview", "qwen3-max-preview", "qwen-plus", "qwen-plus-latest", "qwen-plus-2025-04-28",
        "qwen-flash", "qwen-flash-2025-07-28", "qwen-turbo",
        "qwen3-235b-a22b", "qwen3-32b", "qwen3-30b-a3b", "qwen3-14b", "qwen3-8b",
        "deepseek-v3.2", "deepseek-v3.2-exp", "deepseek-v3.1",
        "glm-5.2-us", "glm-5.2-fast-preview", "glm-5.1", "glm-5", "glm-4.7", "glm-4.6", "kimi-k2.6", "kimi-k2.5"
    ])
}
