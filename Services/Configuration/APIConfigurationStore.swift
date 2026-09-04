import Foundation

/// API 配置统筹服务
/// 负责协调非敏感配置存储与钥匙串敏感密钥存储，确保安全边界隔离
public final class APIConfigurationStore: Sendable {

    public let configurationStorage: ConfigurationStorageProtocol
    public let keychainService: KeychainServiceProtocol

    public init(
        configurationStorage: ConfigurationStorageProtocol = UserDefaultsConfigurationStorage(),
        keychainService: KeychainServiceProtocol = SystemKeychainService()
    ) {
        self.configurationStorage = configurationStorage
        self.keychainService = keychainService
    }

    /// 当前是否已完成有效配置（既有非敏感配置，又在 Keychain 中存有 API Key）
    public var isConfigured: Bool {
        configurationStorage.loadConfiguration() != nil && keychainService.hasAPIKey()
    }

    /// 钥匙串中是否存在 API Key
    public var hasSavedAPIKey: Bool {
        keychainService.hasAPIKey()
    }

    /// 加载当前配置，若未配置则返回默认配置
    public func loadConfiguration() -> APIConfiguration {
        configurationStorage.loadConfiguration() ?? .default
    }

    /// 配置摘要文本，供设置主页直接展示
    public var summaryText: String {
        guard isConfigured, let config = configurationStorage.loadConfiguration() else {
            return "未配置"
        }
        return "\(config.apiFormat.displayName) · \(config.modelID)"
    }

    /// 保存配置与可选的新 API Key
    /// - Parameters:
    ///   - configuration: 非敏感配置对象
    ///   - newAPIKey: 可选的新 API Key（若为空或 nil 则保留现有 Keychain 密钥）
    public func save(configuration: APIConfiguration, newAPIKey: String?) throws {
        // 先存储敏感 API Key 到 Keychain
        if let key = newAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            try keychainService.saveAPIKey(key)
        }
        // 再保存非敏感配置到 UserDefaults
        try configurationStorage.saveConfiguration(configuration)
    }

    /// 清除安全保存的 API Key
    public func clearAPIKey() throws {
        try keychainService.deleteAPIKey()
    }

    /// 清除全部配置与 API Key
    public func clearAll() throws {
        configurationStorage.clearConfiguration()
        try keychainService.deleteAPIKey()
    }
}
