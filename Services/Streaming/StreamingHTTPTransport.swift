import Foundation

public protocol HTTPByteStreaming: Sendable {
    /// 串行等待消费方，避免无限缓冲；返回 false 时立即关闭本次连接。
    func receive(_ request: URLRequest,
                 consume: @escaping @Sendable (Data) async throws -> Bool) async throws
}

public struct URLSessionStreamingTransport: HTTPByteStreaming {
    private let maximumResponseBytes: Int
    private let configurationProvider: @Sendable () -> URLSessionConfiguration

    public init(maximumResponseBytes: Int = 2 * 1024 * 1024,
                configurationProvider: @escaping @Sendable () -> URLSessionConfiguration = {
                    URLSessionHTTPTransport.secureConfiguration()
                }) {
        self.maximumResponseBytes = maximumResponseBytes
        self.configurationProvider = configurationProvider
    }

    public func receive(_ request: URLRequest,
                        consume: @escaping @Sendable (Data) async throws -> Bool) async throws {
        try Task.checkCancellation()
        guard maximumResponseBytes > 0 else { throw StreamingError.invalidRequest }
        let session = URLSession(configuration: configurationProvider(), delegate: NoRedirectDelegate(), delegateQueue: nil)
        try await withTaskCancellationHandler {
            defer { session.invalidateAndCancel() }
            try Task.checkCancellation()
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw StreamingError.invalidEvent }
            guard (200..<300).contains(http.statusCode) else { throw StreamingError.http(http.statusCode) }
            guard http.mimeType?.lowercased() == "text/event-stream" else { throw StreamingError.invalidContentType }
            guard http.expectedContentLength <= Int64(maximumResponseBytes) else { throw StreamingError.responseTooLarge }
            var total = 0
            var chunk = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard total < maximumResponseBytes else { throw StreamingError.responseTooLarge }
                total += 1
                chunk.append(byte)
                // 行尾就交付，不等完整响应或固定大包填满；中文/Emoji 由 SSE 层按完整行解码。
                if byte == 10 || byte == 13 || chunk.count >= 4096 {
                    let shouldContinue = try await consume(chunk)
                    if !shouldContinue { return }
                    chunk.removeAll(keepingCapacity: true)
                }
            }
            try Task.checkCancellation()
            if !chunk.isEmpty { _ = try await consume(chunk) }
        } onCancel: {
            // 即使服务器尚未发首字节或停止发包，也取消实际 URLSession。
            session.invalidateAndCancel()
        }
    }
}
