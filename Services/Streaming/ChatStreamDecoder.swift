import Foundation

struct ChatStreamDecoder: Sendable {
    private var hasText = false
    private var refused = false
    private var unsupported = false
    private var pending: StreamCompletion?
    private var finished = false

    mutating func consume(_ event: ServerSentEvent) throws -> StreamStep {
        guard !finished else { throw StreamingError.invalidEvent }
        guard event.name == "message" else {
            if event.name == "error" { throw StreamingError.generationFailed }
            throw StreamingError.invalidEvent
        }
        if event.data == "[DONE]" {
            guard let pending else { throw StreamingError.unexpectedEnd }
            finished = true
            return StreamStep(completion: pending)
        }
        let chunk = try event.decode(Chunk.self)
        if chunk.error != nil { throw StreamingError.generationFailed }
        guard chunk.object == "chat.completion.chunk", let choices = chunk.choices else {
            throw StreamingError.invalidEvent
        }
        // include_usage 可产生 choices=[]；它不代表结束，也不生成任何文本。
        if choices.isEmpty { return StreamStep() }
        guard choices.count == 1, let choice = choices.first, choice.index == 0,
              pending == nil, let delta = choice.delta else { throw StreamingError.invalidEvent }
        guard delta.role == nil || delta.role == "assistant" else { throw StreamingError.invalidEvent }
        if let refusal = delta.refusal, !refusal.isEmpty { refused = true }
        if delta.tool_calls != nil || delta.function_call != nil { unsupported = true }
        let text = delta.content ?? ""
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { hasText = true }
        if let reason = choice.finish_reason {
            switch reason {
            case "content_filter": pending = .refused
            case "length": pending = refused ? .refused : .outputLimited
            case "stop": pending = refused ? .refused : (unsupported ? .incomplete : (hasText ? .completed : .noText))
            default: pending = refused ? .refused : .incomplete
            }
        }
        return StreamStep(text: text)
    }

    private struct Marker: Decodable {}
    private struct Chunk: Decodable {
        let object: String?; let choices: [Choice]?; let error: Marker?
    }
    private struct Choice: Decodable {
        let index: Int; let delta: Delta?; let finish_reason: String?
    }
    private struct Delta: Decodable {
        let role: String?; let content: String?; let refusal: String?
        let tool_calls: [Marker]?; let function_call: Marker?
    }
}
