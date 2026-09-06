import Foundation

public struct HTTPPayload: Sendable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPPayload
}

/// 每次测试独立的短生命周期会话：不写磁盘缓存、不使用 Cookie/共享凭据、不跟随重定向。
public struct URLSessionHTTPTransport: HTTPTransport {
    private let configurationProvider: @Sendable () -> URLSessionConfiguration
    private let maximumResponseBytes: Int

    public init(
        maximumResponseBytes: Int = 2 * 1024 * 1024,
        configurationProvider: @escaping @Sendable () -> URLSessionConfiguration = { URLSessionHTTPTransport.secureConfiguration() }
    ) {
        self.maximumResponseBytes = maximumResponseBytes
        self.configurationProvider = configurationProvider
    }

    public static func secureConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = ConnectionTestPolicy.timeout
        configuration.timeoutIntervalForResource = ConnectionTestPolicy.timeout
        configuration.waitsForConnectivity = false
        return configuration
    }

    public func send(_ request: URLRequest) async throws -> HTTPPayload {
        try Task.checkCancellation()
        let session = URLSession(configuration: configurationProvider(), delegate: NoRedirectDelegate(), delegateQueue: nil)
        return try await withTaskCancellationHandler {
            defer { session.invalidateAndCancel() }
            try Task.checkCancellation()
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else { throw ConnectionTestError.invalidResponse }
            // 失败正文不读取、不显示，避免异常服务回显密钥或无限传输错误页。
            guard (200..<300).contains(response.statusCode) else {
                return HTTPPayload(statusCode: response.statusCode, body: Data())
            }
            guard response.expectedContentLength <= Int64(maximumResponseBytes) else {
                throw ConnectionTestError.responseTooLarge
            }
            var body = Data()
            for try await byte in bytes {
                if body.count.isMultiple(of: 4096) { try Task.checkCancellation() }
                guard body.count < maximumResponseBytes else { throw ConnectionTestError.responseTooLarge }
                body.append(byte)
            }
            try Task.checkCancellation()
            return HTTPPayload(statusCode: response.statusCode, body: body)
        } onCancel: {
            // 包括服务器迟迟不发送首字节/后续数据的情况，立即取消实际会话。
            session.invalidateAndCancel()
        }
    }
}

/// 不将 Authorization 或 x-api-key 发送至服务器指定的另一个地址。
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
