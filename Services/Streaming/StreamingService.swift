import Foundation

/// 第 5 轮只提供可测试的基础设施；没有任何生产 UI 调用此入口。
public struct StreamingService: Sendable {
    private let transport: any HTTPByteStreaming

    public init(transport: any HTTPByteStreaming = URLSessionStreamingTransport()) {
        self.transport = transport
    }

    /// 增量可能先于失败出现，调用方只能以返回的终态认定完整成功。
    /// 本方法不累积队列、不自动重试；取消当前 Task 即取消传输。
    public func stream(configuration: APIConfiguration, apiKey: String, input: String, outputLimit: Int,
                       onText: @escaping @Sendable (String) async throws -> Void) async throws -> StreamCompletion {
        do {
            try Task.checkCancellation()
            let request = try StreamingRequestBuilder.build(configuration: configuration, apiKey: apiKey,
                                                            input: input, outputLimit: outputLimit)
            let processor = StreamProcessor(format: configuration.apiFormat, onText: onText)
            try await transport.receive(request) { data in try await processor.receive(data) }
            try Task.checkCancellation()
            return try await processor.finish()
        } catch { throw StreamingError.sanitized(error) }
    }
}

private actor StreamProcessor {
    private var sse = SSEDecoder()
    private var decoder: ProtocolStreamDecoder
    private var completion: StreamCompletion?
    private let onText: @Sendable (String) async throws -> Void

    init(format: APIFormat, onText: @escaping @Sendable (String) async throws -> Void) {
        decoder = ProtocolStreamDecoder(format: format)
        self.onText = onText
    }

    func receive(_ data: Data) async throws -> Bool {
        try Task.checkCancellation()
        guard completion == nil else { return false }
        for byte in data {
            try Task.checkCancellation()
            guard let event = try sse.append(byte) else { continue }
            let step = try decoder.consume(event)
            if !step.text.isEmpty {
                try Task.checkCancellation()
                try await onText(step.text)
                try Task.checkCancellation()
            }
            if let terminal = step.completion {
                completion = terminal
                return false
            }
        }
        return true
    }

    func finish() throws -> StreamCompletion {
        try Task.checkCancellation()
        guard let completion else { throw StreamingError.unexpectedEnd }
        return completion
    }
}
