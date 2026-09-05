import Foundation

/// 内存 Mock Keychain 服务，专用于自动化测试
/// 线程安全且绝不操作真实系统钥匙串，提供精确的调用计数统计与失败模拟
public final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String]
    public let service: String
    public let account: String

    /// 记录各操作调用的实际次数，供单元测试做精准断言
    public private(set) var updateCallCount: Int = 0
    public private(set) var addCallCount: Int = 0
    public private(set) var deleteCallCount: Int = 0

    /// 模拟更新失败的错误注入点
    public var simulateUpdateError: (any Error)? = nil

    public init(
        service: String = SystemKeychainService.defaultService,
        account: String = SystemKeychainService.defaultAccount,
        initialStorage: [String: String] = [:]
    ) {
        self.service = service
        self.account = account
        self.storage = initialStorage
    }

    private var storageKey: String {
        "\(service).\(account)"
    }

    public func saveAPIKey(_ apiKey: String) throws {
        lock.lock()
        defer { lock.unlock() }

        if storage[storageKey] != nil {
            updateCallCount += 1
            if let error = simulateUpdateError {
                // 模拟更新失败：不修改任何原有存储，直接抛出错误
                throw error
            }
            storage[storageKey] = apiKey
        } else {
            addCallCount += 1
            storage[storageKey] = apiKey
        }
    }

    public func readAPIKey() throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let key = storage[storageKey] else {
            throw KeychainError.itemNotFound
        }
        return key
    }

    public func hasAPIKey() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[storageKey] != nil
    }

    public func deleteAPIKey() throws {
        lock.lock()
        defer { lock.unlock() }
        deleteCallCount += 1
        storage.removeValue(forKey: storageKey)
    }

    /// 测试辅助重置方法
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        updateCallCount = 0
        addCallCount = 0
        deleteCallCount = 0
        simulateUpdateError = nil
        storage.removeAll()
    }
}
