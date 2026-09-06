import Foundation

/// HTTP 2xx 不等于协议成功；必须识别响应结构与结束原因。正文仅瞬时解析，不返回给界面/日志。
public enum APIProbeResponseParser {
    public static func parse(_ data: Data, format: APIFormat) throws -> ConnectionTestOutcome {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            switch format {
            case .openAIResponses:
                let response = try decoder.decode(ResponsesEnvelope.self, from: data)
                guard response.object == "response" else { throw ConnectionTestError.invalidResponse }
                guard response.error == nil else { throw ConnectionTestError.generationFailed }
                switch response.status {
                case "incomplete":
                    return response.incompleteDetails?.reason == "max_output_tokens" ? .outputLimited : .incomplete
                case "completed": break
                default: throw ConnectionTestError.generationFailed
                }
                let content = response.output.filter { $0.type == "message" && $0.role == "assistant" }
                    .flatMap { $0.content ?? [] }
                if content.contains(where: { $0.type == "refusal" }) { return .refused }
                return content.contains(where: { $0.type == "output_text" && hasText($0.text) }) ? .success : .noText
            case .openAIChatCompletions:
                let response = try decoder.decode(ChatEnvelope.self, from: data)
                guard response.object == "chat.completion", let choice = response.choices.first,
                      choice.message.role == "assistant", let reason = choice.finishReason else {
                    throw ConnectionTestError.invalidResponse
                }
                guard response.error == nil else { throw ConnectionTestError.generationFailed }
                if reason == "length" { return .outputLimited }
                if reason == "content_filter" || hasText(choice.message.refusal) { return .refused }
                guard reason == "stop" else { return .incomplete }
                return hasText(choice.message.content) ? .success : .noText
            case .anthropicMessages:
                let response = try decoder.decode(MessagesEnvelope.self, from: data)
                guard response.type == "message", response.role == "assistant", let reason = response.stopReason else {
                    throw ConnectionTestError.invalidResponse
                }
                guard response.error == nil else { throw ConnectionTestError.generationFailed }
                if reason == "max_tokens" { return .outputLimited }
                if reason == "refusal" || response.stopDetails?.type == "refusal" ||
                    response.content.contains(where: { $0.type == "refusal" }) { return .refused }
                guard reason == "end_turn" || reason == "stop_sequence" else { return .incomplete }
                return response.content.contains(where: { $0.type == "text" && hasText($0.text) }) ? .success : .noText
            }
        } catch let error as ConnectionTestError {
            throw error
        } catch {
            // 不传播 DecodingError 的原始上下文，避免服务器回显敏感值。
            throw ConnectionTestError.invalidResponse
        }
    }

    private static func hasText(_ text: String?) -> Bool {
        !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private struct ErrorMarker: Decodable {}
    private struct Content: Decodable { let type: String; let text: String? }
    private struct ResponsesEnvelope: Decodable {
        let object: String
        let status: String
        let output: [Output]
        let error: ErrorMarker?
        let incompleteDetails: IncompleteDetails?
        struct Output: Decodable { let type: String; let role: String?; let content: [Content]? }
        struct IncompleteDetails: Decodable { let reason: String }
    }
    private struct ChatEnvelope: Decodable {
        let object: String
        let choices: [Choice]
        let error: ErrorMarker?
        struct Choice: Decodable {
            let message: Message
            let finishReason: String?
        }
        struct Message: Decodable { let role: String; let content: String?; let refusal: String? }
    }
    private struct MessagesEnvelope: Decodable {
        let type: String
        let role: String
        let content: [Content]
        let stopReason: String?
        let stopDetails: StopDetails?
        let error: ErrorMarker?
        struct StopDetails: Decodable { let type: String }
    }
}
