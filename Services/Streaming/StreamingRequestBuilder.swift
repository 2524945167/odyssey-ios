import Foundation

/// 通用传输入口，不决定翻译提示词，也不读取首页、设置或钥匙串。
/// input 与 outputLimit 均须由调用方显式传入；不借用连接测试的 256 默认值。
public enum StreamingRequestBuilder {
    public static func build(configuration: APIConfiguration, apiKey: String,
                             input: String, outputLimit: Int) throws -> URLRequest {
        do {
            guard outputLimit > 0, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StreamingError.invalidRequest
            }
            try APIConfigurationValidator.validateModelID(configuration.modelID)
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, key.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }) else {
                throw StreamingError.invalidRequest
            }
            var request = URLRequest(url: try APIProbeRequestBuilder.endpoint(for: configuration))
            request.httpMethod = "POST"
            // 延续现有网络安全边界；不是正式翻译界面的超时/预算设置。
            request.timeoutInterval = ConnectionTestPolicy.timeout
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.httpShouldHandleCookies = false
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            let model = configuration.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
            let encoder = JSONEncoder()
            switch configuration.apiFormat {
            case .openAIResponses:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                request.httpBody = try encoder.encode(ResponsesBody(model: model, input: input, max_output_tokens: outputLimit))
            case .openAIChatCompletions:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                request.httpBody = try encoder.encode(ChatBody(model: model, messages: [Message(content: input)], max_completion_tokens: outputLimit))
            case .anthropicMessages:
                request.setValue(key, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                request.httpBody = try encoder.encode(MessagesBody(model: model, messages: [Message(content: input)], max_tokens: outputLimit))
            }
            return request
        } catch { throw StreamingError.sanitized(error) }
    }

    private struct Message: Encodable { let role = "user"; let content: String }
    private struct ResponsesBody: Encodable {
        let model: String; let input: String; let max_output_tokens: Int
        let stream = true; let store = false
    }
    private struct ChatBody: Encodable {
        let model: String; let messages: [Message]; let max_completion_tokens: Int
        let stream = true; let store = false
    }
    private struct MessagesBody: Encodable {
        let model: String; let messages: [Message]; let max_tokens: Int
        let stream = true
    }
}
