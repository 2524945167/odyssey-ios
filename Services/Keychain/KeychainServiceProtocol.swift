import Foundation

/// 脱敏 Keychain 错误枚举
public enum KeychainError: LocalizedError, Equatable, Sendable {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case conversionError

    public var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Keychain 条目已存在"
        case .itemNotFound:
            return "未在系统钥匙串中找到已保存的 API Key"
        case .unexpectedStatus(let status):
            return "钥匙串操作失败（错误码: \(status)）"
        case .conversionError:
            return "密钥数据编码转换失败"
        }
    }
}

/// 钥匙串访问协议
public protocol KeychainServiceProtocol: Sendable {
    func saveAPIKey(_ apiKey: String) throws
    func readAPIKey() throws -> String
    func hasAPIKey() -> Bool
    func deleteAPIKey() throws
}
