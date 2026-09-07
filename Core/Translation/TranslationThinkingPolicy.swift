import Foundation

/// 已核实的服务/模型白名单。绝不向任意 OpenAI 兼容服务发送 Qwen 专用字段。
public enum TranslationThinkingPolicy {
    public static func supports(_ configuration: APIConfiguration?) -> Bool {
        guard let configuration,
              [.openAIChatCompletions, .openAIResponses].contains(configuration.apiFormat),
              ["qwen3.7-flash", "qwen3.7-flash-2026-07-15"].contains(
                configuration.modelID.trimmingCharacters(in: .whitespacesAndNewlines)),
              let url = URLComponents(string: configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host?.lowercased(),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.port == nil || url.port == 443 else { return false }
        var path = url.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        guard path == "/compatible-mode/v1" ||
                (configuration.apiFormat == .openAIResponses && path == "/api/v2/apps/protocols/compatible-mode/v1") else { return false }
        if ["dashscope.aliyuncs.com", "dashscope-intl.aliyuncs.com", "cn-hongkong.dashscope.aliyuncs.com"].contains(host) { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        let regions = ["cn-beijing", "ap-southeast-1", "cn-hongkong", "us-east-1", "eu-central-1", "ap-northeast-1"]
        return parts.count == 5 && !parts[0].isEmpty &&
            parts[0].utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 } &&
            regions.contains(String(parts[1])) && parts[2] == "maas" && parts[3] == "aliyuncs" && parts[4] == "com"
    }
}
