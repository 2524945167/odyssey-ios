import Foundation
import Observation

/// 只保存翻译参数与用户主动编辑的风格模板，不保存翻译正文或 API 凭据。
@Observable
@MainActor
public final class TranslationPreferences {
    public static let optionsKey = "com.kupetis.odyssey.translation.options"
    public static let stylesKey = "com.kupetis.odyssey.translation.styles"
    @ObservationIgnored private let defaults: UserDefaults
    public private(set) var styles: TranslationStyleConfiguration

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var saved = defaults.data(forKey: Self.stylesKey).flatMap {
            try? JSONDecoder().decode(TranslationStyleConfiguration.self, from: $0)
        } ?? TranslationStyleConfiguration()
        saved.overrides = saved.overrides.filter { key, value in
            guard let style = TranslationStyle(rawValue: key) else { return false }
            return style == .custom || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        styles = saved
    }

    public var options: TranslationOptions {
        let saved = defaults.dictionary(forKey: Self.optionsKey) ?? [:]
        let output = saved["outputLimit"] as? Int ?? 0
        let timeout = saved["idleTimeoutSeconds"] as? Int ?? 0
        return TranslationOptions(
            outputLimit: output > 0 ? output : TranslationOptions.defaultOutputLimit,
            idleTimeoutSeconds: timeout > 0 ? timeout : TranslationOptions.defaultIdleTimeoutSeconds,
            thinkingEnabled: saved["thinkingEnabled"] as? Bool ?? false,
            style: styles.selectedStyle, styleInstructions: styles.instructions(for: styles.selectedStyle)
        )
    }

    public func save(_ options: TranslationOptions) throws {
        guard options.isValid else { throw StreamingError.invalidRequest }
        let saved: [String: Any] = ["outputLimit": options.outputLimit, "idleTimeoutSeconds": options.idleTimeoutSeconds,
                                    "thinkingEnabled": options.thinkingEnabled]
        defaults.set(saved, forKey: Self.optionsKey)
    }

    public func selectStyle(_ style: TranslationStyle) {
        var updated = styles
        updated.selectedStyle = style
        persistStyles(updated)
    }

    @discardableResult
    public func saveTemplate(_ text: String, for style: TranslationStyle) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard style == .custom || !value.isEmpty else { return false }
        var updated = styles
        if value == style.defaultInstructions { updated.overrides.removeValue(forKey: style.rawValue) }
        else { updated.overrides[style.rawValue] = value }
        persistStyles(updated)
        return true
    }

    private func persistStyles(_ updated: TranslationStyleConfiguration) {
        // 仅含 Codable 的枚举/字符串字典；编码不能失败，不涉及外部资源。
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: Self.stylesKey)
        styles = updated
    }
}
