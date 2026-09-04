import Foundation

/// 基于 UserDefaults 的轻量配置存储
/// 绝对不存储 API Key
public final class UserDefaultsConfigurationStorage: ConfigurationStorageProtocol, @unchecked Sendable {

    public static let defaultStorageKey = "com.kupetis.odyssey.api_configuration"

    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = UserDefaultsConfigurationStorage.defaultStorageKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    public func loadConfiguration() -> APIConfiguration? {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(APIConfiguration.self, from: data)
        } catch {
            return nil
        }
    }

    public func saveConfiguration(_ configuration: APIConfiguration) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(configuration)
        userDefaults.set(data, forKey: storageKey)
    }

    public func clearConfiguration() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
