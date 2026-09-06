import Foundation

/// 三种明确协议，无自动探测、降级或额外请求。
public enum APIProbeRequestBuilder {
    public static func endpoint(for configuration: APIConfiguration) throws -> URL {
        try APIConfigurationValidator.validateBaseURL(configuration.baseURL)
        let base = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: base) else {
            throw ConnectionTestError.invalidConfiguration(.invalidURL)
        }
        // 保留用户自定义路径与编码；只去掉末尾斜杠，不猜测或重复添加 /v1。
        while components.percentEncodedPath.hasSuffix("/") {
            components.percentEncodedPath.removeLast()
        }
        let suffix: String
        switch configuration.apiFormat {
        case .openAIResponses: suffix = "/responses"
        case .openAIChatCompletions: suffix = "/chat/completions"
        case .anthropicMessages: suffix = "/messages"
        }
        components.percentEncodedPath += suffix
        guard let url = components.url else {
            throw ConnectionTestError.invalidConfiguration(.invalidURL)
        }
        return url
    }

    public static func build(configuration: APIConfiguration, apiKey: String, outputLimit: Int) throws -> URLRequest {
        guard outputLimit > 0 else { throw ConnectionTestError.invalidOutputLimit }
        try APIConfigurationValidator.validateModelID(configuration.modelID)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }) else {
            throw ConnectionTestError.invalidAPIKey
        }
        var request = URLRequest(url: try endpoint(for: configuration))
        request.httpMethod = "POST"
        request.timeoutInterval = ConnectionTestPolicy.timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let model = configuration.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoder = JSONEncoder()
        switch configuration.apiFormat {
        case .openAIResponses:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.httpBody = try encoder.encode(ResponsesBody(model: model, max_output_tokens: outputLimit))
        case .openAIChatCompletions:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.httpBody = try encoder.encode(ChatBody(model: model, max_completion_tokens: outputLimit))
        case .anthropicMessages:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try encoder.encode(MessagesBody(model: model, max_tokens: outputLimit))
        }
        return request
    }

    private struct ProbeMessage: Encodable {
        let role = "user"
        let content = ConnectionTestPolicy.prompt
    }
    private struct ResponsesBody: Encodable {
        let model: String
        let max_output_tokens: Int
        let input = ConnectionTestPolicy.prompt
        let stream = false
        let store = false
    }
    private struct ChatBody: Encodable {
        let model: String
        let max_completion_tokens: Int
        let messages = [ProbeMessage()]
        let stream = false
        let store = false
    }
    private struct MessagesBody: Encodable {
        let model: String
        let max_tokens: Int
        let messages = [ProbeMessage()]
        let stream = false
    }
}
