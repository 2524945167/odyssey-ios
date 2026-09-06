import Foundation

struct MessagesStreamDecoder: Sendable {
    private struct Block: Sendable { let kind: String; var open = true }
    private var started = false
    private var finished = false
    private var blocks: [Int: Block] = [:]
    private var lastIndex = -1
    private var hasText = false
    private var unsupported = false
    private var refusal = false
    private var stopReason: String?

    mutating func consume(_ event: ServerSentEvent) throws -> StreamStep {
        guard !finished else { throw StreamingError.invalidEvent }
        let header = try event.decode(StreamEventHeader.self)
        guard event.name == "message" || event.name == header.type else { throw StreamingError.invalidEvent }
        if header.type == "error" { throw StreamingError.generationFailed }
        if header.type == "ping" { return StreamStep() }
        if header.type == "message_start" {
            let start = try event.decode(StartEvent.self).message
            guard !started, start.type == "message", start.role == "assistant", !start.id.isEmpty,
                  start.content.isEmpty else { throw StreamingError.invalidEvent }
            started = true
            return StreamStep()
        }
        guard started, !header.type.hasPrefix("response.") else { throw StreamingError.invalidEvent }
        switch header.type {
        case "content_block_start":
            let root = try event.decode(BlockStart.self)
            guard stopReason == nil, root.index > lastIndex else { throw StreamingError.invalidEvent }
            lastIndex = root.index
            blocks[root.index] = Block(kind: root.content_block.type)
            if root.content_block.type == "text" {
                guard let text = root.content_block.text else { throw StreamingError.invalidEvent }
                noteText(text)
                return StreamStep(text: text)
            }
            if !["thinking", "redacted_thinking"].contains(root.content_block.type) { unsupported = true }
            return StreamStep()
        case "content_block_delta":
            let root = try event.decode(BlockDelta.self)
            guard stopReason == nil, let block = blocks[root.index], block.open else { throw StreamingError.invalidEvent }
            if root.delta.type == "text_delta" {
                guard block.kind == "text", let text = root.delta.text else { throw StreamingError.invalidEvent }
                noteText(text)
                return StreamStep(text: text)
            }
            // 推理/签名/工具输入不当作文本；未知增量类型不导致协议切换。
            return StreamStep()
        case "content_block_stop":
            let root = try event.decode(BlockStop.self)
            guard stopReason == nil, var block = blocks[root.index], block.open else { throw StreamingError.invalidEvent }
            block.open = false
            blocks[root.index] = block
            return StreamStep()
        case "message_delta":
            let root = try event.decode(MessageDelta.self)
            if let reason = root.delta.stop_reason {
                guard stopReason == nil, blocks.values.allSatisfy({ !$0.open }) else { throw StreamingError.invalidEvent }
                stopReason = reason
                refusal = root.delta.stop_details?.type == "refusal" || reason == "refusal"
            }
            return StreamStep()
        case "message_stop":
            guard let reason = stopReason, blocks.values.allSatisfy({ !$0.open }) else { throw StreamingError.unexpectedEnd }
            finished = true
            if refusal { return StreamStep(completion: .refused) }
            if reason == "max_tokens" { return StreamStep(completion: .outputLimited) }
            if unsupported || !["end_turn", "stop_sequence"].contains(reason) { return StreamStep(completion: .incomplete) }
            return StreamStep(completion: hasText ? .completed : .noText)
        default:
            // 官方要求兼容未来事件类型，但未知事件永远不能构成成功终态。
            return StreamStep()
        }
    }

    private mutating func noteText(_ text: String) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { hasText = true }
    }
    private struct Marker: Decodable {}
    private struct StartEvent: Decodable { let message: Message }
    private struct Message: Decodable { let id: String; let type: String; let role: String; let content: [Marker] }
    private struct BlockStart: Decodable { let index: Int; let content_block: ContentBlock }
    private struct ContentBlock: Decodable { let type: String; let text: String? }
    private struct BlockDelta: Decodable { let index: Int; let delta: ContentDelta }
    private struct ContentDelta: Decodable { let type: String; let text: String? }
    private struct BlockStop: Decodable { let index: Int }
    private struct MessageDelta: Decodable { let delta: StopDelta }
    private struct StopDelta: Decodable { let stop_reason: String?; let stop_details: StopDetails? }
    private struct StopDetails: Decodable { let type: String }
}
