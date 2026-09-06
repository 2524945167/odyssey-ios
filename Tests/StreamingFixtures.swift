import Foundation
@testable import Odyssey

/// 所有数据均为本地构造，不包含真实接口响应或用户凭据。
enum StreamingFixtures {
    static let text = "你好🌏\ne\u{301}!"
    static let parts = ["你", "好", "🌏", "\n", "e", "\u{301}", "!"]
    static let key = "fixture-stream-key"

    static func json(_ object: [String: Any]) -> String {
        // 测试作者控制的 JSON 字面量；失败表示测试夹具自身错误。
        String(decoding: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self)
    }
    static func event(_ object: [String: Any], named: Bool = true) -> String {
        let name = named ? (object["type"] as? String).map { "event: \($0)\n" } ?? "" : ""
        return name + "data: " + json(object) + "\n\n"
    }
    static let responsesStart = event([
        "type": "response.created", "response": ["id": "resp_fixture", "object": "response", "status": "in_progress", "output": []]
    ])
    static func responsesDelta(_ value: String, sequence: Int? = nil) -> String {
        var object: [String: Any] = ["type": "response.output_text.delta", "delta": value, "output_index": 0, "content_index": 0, "item_id": "msg_fixture"]
        if let sequence { object["sequence_number"] = sequence }
        return event(object)
    }
    static func responsesEnd(_ text: String = StreamingFixtures.text, reason: String? = nil, refusal: Bool = false) -> String {
        var content: [[String: Any]] = [["type": "output_text", "text": text]]
        if refusal { content.append(["type": "refusal", "refusal": "fixture-refusal"]) }
        var response: [String: Any] = ["id": "resp_fixture", "object": "response", "status": reason == nil ? "completed" : "incomplete",
                                       "output": [["type": "reasoning", "summary": []], ["type": "message", "role": "assistant", "content": content]]]
        if let reason { response["incomplete_details"] = ["reason": reason] }
        return event(["type": reason == nil ? "response.completed" : "response.incomplete", "response": response])
    }
    static func chat(_ text: String? = nil, finish: String? = nil, refusal: String? = nil) -> String {
        var delta: [String: Any] = [:]
        if let text { delta["content"] = text }
        if let refusal { delta["refusal"] = refusal }
        var choice: [String: Any] = ["index": 0, "delta": delta]
        if let finish { choice["finish_reason"] = finish }
        return event(["object": "chat.completion.chunk", "choices": [choice]], named: false)
    }
    static let done = "data: [DONE]\n\n"
    static let messagesStart = event(["type": "message_start", "message": ["id": "msg_fixture", "type": "message", "role": "assistant", "content": []]])
    static func blockStart(_ index: Int, kind: String = "text", text: String = "") -> String {
        event(["type": "content_block_start", "index": index, "content_block": ["type": kind, "text": text]])
    }
    static func messagesDelta(_ text: String, index: Int = 0, type: String = "text_delta") -> String {
        event(["type": "content_block_delta", "index": index, "delta": ["type": type, "text": text]])
    }
    static func blockStop(_ index: Int) -> String { event(["type": "content_block_stop", "index": index]) }
    static func messageReason(_ reason: String, refusal: Bool = false) -> String {
        var delta: [String: Any] = ["stop_reason": reason]
        if refusal { delta["stop_details"] = ["type": "refusal"] }
        return event(["type": "message_delta", "delta": delta, "usage": ["output_tokens": 12]])
    }
    static let messagesStop = event(["type": "message_stop"])

    static func partial(_ format: APIFormat, parts: [String] = StreamingFixtures.parts) -> String {
        switch format {
        case .openAIResponses: return responsesStart + parts.map { responsesDelta($0) }.joined()
        case .openAIChatCompletions:
            return event(["object": "chat.completion.chunk", "choices": [["index": 0, "delta": ["role": "assistant", "content": ""]]]], named: false)
                + parts.map { chat($0) }.joined()
        case .anthropicMessages: return messagesStart + blockStart(0) + parts.map { messagesDelta($0) }.joined() + blockStop(0)
        }
    }
    static func success(_ format: APIFormat) -> String {
        let tail: String
        switch format {
        case .openAIResponses:
            tail = event(["type": "response.output_text.done", "text": text]) + responsesEnd()
        case .openAIChatCompletions:
            tail = chat(finish: "stop") + event(["object": "chat.completion.chunk", "choices": [], "usage": ["total_tokens": 12]], named: false) + done
        case .anthropicMessages: tail = messageReason("end_turn") + messagesStop
        }
        return partial(format) + tail
    }
    static func chunks(_ string: String, size: Int = 1) -> [Data] {
        let data = Array(string.utf8)
        return stride(from: 0, to: data.count, by: size).map { Data(data[$0..<min($0 + size, data.count)]) }
    }
}

actor StreamTextRecorder {
    private(set) var pieces: [String] = []
    func append(_ value: String) { pieces.append(value) }
    var text: String { pieces.joined() }
}

actor FixtureByteTransport: HTTPByteStreaming {
    private let chunks: [Data]
    private let failure: URLError?
    private(set) var requests: [URLRequest] = []
    private(set) var deliveredChunks = 0
    init(_ content: String, chunkSize: Int = 1, failure: URLError? = nil) {
        chunks = StreamingFixtures.chunks(content, size: chunkSize)
        self.failure = failure
    }
    func receive(_ request: URLRequest, consume: @escaping @Sendable (Data) async throws -> Bool) async throws {
        requests.append(request)
        for chunk in chunks {
            try Task.checkCancellation()
            deliveredChunks += 1
            if try await consume(chunk) == false { return }
        }
        if let failure { throw failure }
    }
}
