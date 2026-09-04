import Foundation

/// 内存 Mock 配置存储，专用于自动化测试
public final class MockConfigurationStorage: ConfigurationStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var configuration: APIConfiguration?

    public init(initialConfiguration: APIConfiguration? = nil) {
        self.configuration = initialConfiguration
    }

    public func loadConfiguration() -> APIConfiguration? {
        lock.lock()
        defer { lock.unlock() }
        return configuration
    }

    public func saveConfiguration(_ configuration: APIConfiguration) throws {
        lock.lock()
        defer { lock.unlock() }
        self.configuration = configuration
    }

    public func clearConfiguration() {
        lock.lock()
        defer { lock.unlock() }
        self.configuration = nil
    }
}
