import Foundation

/// 只保存连接测试的非敏感数值，不改变已有 API 配置 JSON 或钥匙串。
@MainActor
public final class ConnectionTestPreferences {
    public static let outputLimitKey = "com.kupetis.odyssey.connection_test.output_limit"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var outputLimit: Int {
        let value = defaults.integer(forKey: Self.outputLimitKey)
        return value > 0 ? value : ConnectionTestPolicy.defaultOutputLimit
    }

    public func saveOutputLimit(_ value: Int) throws {
        guard value > 0 else { throw ConnectionTestError.invalidOutputLimit }
        defaults.set(value, forKey: Self.outputLimitKey)
    }
}
