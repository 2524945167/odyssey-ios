import Foundation
import Security

/// 基于系统 Keychain 的安全密钥存储实现
/// 严格遵循 kSecAttrAccessibleWhenUnlockedThisDeviceOnly 隔离要求
public final class SystemKeychainService: KeychainServiceProtocol, Sendable {

    public static let defaultService = "com.kupetis.odyssey.apikey"
    public static let defaultAccount = "odyssey_active_api_key"

    public let service: String
    public let account: String

    public init(
        service: String = SystemKeychainService.defaultService,
        account: String = SystemKeychainService.defaultAccount
    ) {
        self.service = service
        self.account = account
    }

    /// 安全保存 API Key
    /// 严禁先 SecItemDelete 再 SecItemAdd。已存在时使用 SecItemUpdate；不存在时使用 SecItemAdd。
    /// 更新失败时绝不删除原密钥，确保原凭据完好保留。
    public func saveAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.conversionError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        } else if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else {
            // 更新失败，禁止删除，直接抛出异常，原密钥完好保留在 Keychain 中
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    public func readAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data, let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.conversionError
        }

        return apiKey
    }

    public func hasAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
