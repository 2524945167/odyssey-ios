import Foundation

extension ServerSentEvent {
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        do { return try JSONDecoder().decode(type, from: Data(data.utf8)) }
        catch { throw StreamingError.invalidEvent }
    }
}

struct StreamEventHeader: Decodable {
    let type: String
    let sequence_number: Int?
}

struct ResponsesStreamDecoder: Sendable {
    private var responseID: String?
    private var lastSequence: Int?
    private var receivedText = ""
    private var refused = false
    private var finished = false

    mutating func consume(_ event: ServerSentEvent) throws -> StreamStep {
        guard !finished else { throw StreamingError.invalidEvent }
        let header = try event.decode(StreamEventHeader.self)
        guard event.name == "message" || event.name == header.type else { throw StreamingError.invalidEvent }
        if header.type == "error" { throw StreamingError.generationFailed }
        guard header.type.hasPrefix("response.") else { throw StreamingError.invalidEvent }
        if let sequence = header.sequence_number {
            guard sequence >= 0, lastSequence.map({ sequence > $0 }) ?? true else { throw StreamingError.invalidEvent }
            lastSequence = sequence
        }
        if header.type == "response.created" {
            let root = try event.decode(ResponseEvent.self)
            guard responseID == nil, root.response.object == "response", !root.response.id.isEmpty,
                  ["in_progress", "queued"].contains(root.response.status) else { throw StreamingError.invalidEvent }
            responseID = root.response.id
            return StreamStep()
        }
        guard responseID != nil else { throw StreamingError.invalidEvent }
        switch header.type {
        case "response.output_text.delta":
            let delta = try event.decode(TextDelta.self)
            guard delta.output_index >= 0, delta.content_index >= 0, !delta.item_id.isEmpty else {
                throw StreamingError.invalidEvent
            }
            receivedText += delta.delta
            return StreamStep(text: delta.delta)
        case "response.refusal.delta", "response.refusal.done":
            refused = true
            return StreamStep()
        case "response.failed":
            throw StreamingError.generationFailed
        case "response.completed", "response.incomplete":
            let result = try event.decode(ResponseEvent.self).response
            guard result.id == responseID, result.object == "response", result.error == nil,
                  result.status == (header.type == "response.completed" ? "completed" : "incomplete"),
                  let output = result.output else { throw StreamingError.invalidEvent }
            var finalText = ""
            var unsupported = false
            for item in output {
                if item.type == "reasoning" { continue }
                guard item.type == "message" else { unsupported = true; continue }
                guard item.role == "assistant", let content = item.content else { throw StreamingError.invalidEvent }
                for part in content {
                    switch part.type {
                    case "output_text":
                        guard let text = part.text else { throw StreamingError.invalidEvent }
                        finalText += text
                    case "refusal": refused = true
                    default: unsupported = true
                    }
                }
            }
            // 完整快照用于核对，不再次输出，避免 delta + done/completed 双份文字。
            guard finalText == receivedText else { throw StreamingError.invalidEvent }
            finished = true
            if refused { return StreamStep(completion: .refused) }
            if result.status == "incomplete" {
                let limit = ["max_output_tokens", "max_tokens"].contains(result.incomplete_details?.reason ?? "")
                return StreamStep(completion: limit ? .outputLimited : .incomplete)
            }
            if unsupported { return StreamStep(completion: .incomplete) }
            return StreamStep(completion: receivedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .noText : .completed)
        default:
            // output_text.done、推理、用量及未来 response.* 元数据不是可追加的文本。
            return StreamStep()
        }
    }

    private struct TextDelta: Decodable {
        let delta: String; let output_index: Int; let content_index: Int; let item_id: String
    }
    private struct ResponseEvent: Decodable { let response: Response }
    private struct Response: Decodable {
        let id: String; let object: String; let status: String
        let output: [Output]?
        let error: ErrorMarker?
        let incomplete_details: Incomplete?
    }
    private struct ErrorMarker: Decodable {}
    private struct Incomplete: Decodable { let reason: String }
    private struct Output: Decodable { let type: String; let role: String?; let content: [Content]? }
    private struct Content: Decodable { let type: String; let text: String? }
}
