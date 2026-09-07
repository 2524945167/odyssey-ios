import Foundation

/// 只保存两个非敏感整数，不保存原文、译文、API 配置或凭据。
@MainActor
public final class TranslationPreferences {
    public static let optionsKey = "com.kupetis.odyssey.translation.options"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var options: TranslationOptions {
        let saved = defaults.dictionary(forKey: Self.optionsKey) ?? [:]
        let output = saved["outputLimit"] as? Int ?? 0
        let timeout = saved["idleTimeoutSeconds"] as? Int ?? 0
        return TranslationOptions(
            outputLimit: output > 0 ? output : TranslationOptions.defaultOutputLimit,
            idleTimeoutSeconds: timeout > 0 ? timeout : TranslationOptions.defaultIdleTimeoutSeconds
        )
    }

    public func save(_ options: TranslationOptions) throws {
        guard options.isValid else { throw StreamingError.invalidRequest }
        defaults.set(["outputLimit": options.outputLimit, "idleTimeoutSeconds": options.idleTimeoutSeconds],
                     forKey: Self.optionsKey)
    }
}
