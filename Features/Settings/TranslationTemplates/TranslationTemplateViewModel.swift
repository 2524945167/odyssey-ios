import Foundation
import Observation

@Observable
@MainActor
public final class TranslationTemplateViewModel {
    public let style: TranslationStyle
    public var text: String {
        didSet { error = nil; didSave = false }
    }
    public private(set) var error: String?
    public private(set) var didSave = false
    @ObservationIgnored private let preferences: TranslationPreferences

    public init(style: TranslationStyle, preferences: TranslationPreferences) {
        self.style = style
        self.preferences = preferences
        text = preferences.styles.instructions(for: style)
    }

    public func restoreDefaults() { text = style.defaultInstructions }

    @discardableResult
    public func save() -> Bool {
        guard preferences.saveTemplate(text, for: style) else {
            error = "预设模板不能为空；可以恢复默认值后再保存。"
            didSave = false
            return false
        }
        text = preferences.styles.instructions(for: style)
        didSave = true
        return true
    }
}
