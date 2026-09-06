import Foundation

struct ServerSentEvent: Equatable, Sendable {
    let name: String
    let data: String
}

/// 按字节分行，UTF-8 字符跨网络包时不会被提前解码。只在空行派发事件。
/// 不实现 EventSource 的自动重连；id/retry 字段不触发请求或持久化。
struct SSEDecoder: Sendable {
    private let maximumEventBytes: Int
    private var line: [UInt8] = []
    private var dataLines: [String] = []
    private var eventName = ""
    private var skipLF = false
    private var firstLine = true
    private var eventBytes = 0

    init(maximumEventBytes: Int = 2 * 1024 * 1024) {
        self.maximumEventBytes = maximumEventBytes
    }

    mutating func append(_ byte: UInt8) throws -> ServerSentEvent? {
        if skipLF {
            skipLF = false
            if byte == 10 { return nil }
        }
        guard eventBytes < maximumEventBytes else { throw StreamingError.responseTooLarge }
        eventBytes += 1
        if byte == 13 {
            skipLF = true
            return try finishLine()
        }
        if byte == 10 { return try finishLine() }
        line.append(byte)
        return nil
    }

    private mutating func finishLine() throws -> ServerSentEvent? {
        guard var value = String(bytes: line, encoding: .utf8) else { throw StreamingError.invalidEvent }
        line.removeAll(keepingCapacity: true)
        if firstLine {
            firstLine = false
            if value.hasPrefix("\u{feff}") { value.removeFirst() }
        }
        if value.isEmpty {
            defer {
                dataLines.removeAll(keepingCapacity: true)
                eventName = ""
                eventBytes = 0
            }
            guard !dataLines.isEmpty else { return nil }
            return ServerSentEvent(name: eventName.isEmpty ? "message" : eventName,
                                   data: dataLines.joined(separator: "\n"))
        }
        if value.hasPrefix(":") { return nil }
        let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = String(parts[0])
        var content = parts.count == 2 ? String(parts[1]) : ""
        if content.hasPrefix(" ") { content.removeFirst() }
        switch field {
        case "event": eventName = content
        case "data": dataLines.append(content)
        default: break
        }
        return nil
    }
    // EOF 不补空行、不派发残缺事件；上层必须已收到所选协议的完整终态。
}
