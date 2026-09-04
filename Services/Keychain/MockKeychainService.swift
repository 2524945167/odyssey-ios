import Foundation

/// 内存 Mock Keychain 服务，专用于自动化测试
/// 线程安全且绝不操作真实系统钥匙串
public final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String]
    public let service: String
    public let account: String

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
        storage[storageKey] = apiKey
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
        storage.removeValue(forKey: storageKey)
    }

    /// 测试辅助重置方法
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
