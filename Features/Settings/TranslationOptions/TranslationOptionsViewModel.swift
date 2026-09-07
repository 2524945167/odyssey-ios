import Foundation
import Observation

@Observable
@MainActor
public final class TranslationOptionsViewModel {
    public var outputLimitText: String {
        didSet { outputLimitError = nil; didSave = false }
    }
    public var idleTimeoutText: String {
        didSet { idleTimeoutError = nil; didSave = false }
    }
    public var thinkingEnabled: Bool { didSet { didSave = false } }
    public private(set) var outputLimitError: String?
    public private(set) var idleTimeoutError: String?
    public private(set) var didSave = false
    @ObservationIgnored private let preferences: TranslationPreferences

    public init(preferences: TranslationPreferences = TranslationPreferences()) {
        self.preferences = preferences
        let options = preferences.options
        outputLimitText = String(options.outputLimit)
        idleTimeoutText = String(options.idleTimeoutSeconds)
        thinkingEnabled = options.thinkingEnabled
    }

    public func restoreDefaults() {
        outputLimitText = String(TranslationOptions.defaultOutputLimit)
        idleTimeoutText = String(TranslationOptions.defaultIdleTimeoutSeconds)
        thinkingEnabled = false
    }

    @discardableResult
    public func save() -> Bool {
        let output = TranslationOptions.positiveInteger(from: outputLimitText)
        let timeout = TranslationOptions.positiveInteger(from: idleTimeoutText)
        outputLimitError = output == nil ? "请输入大于 0 的整数，数值不能超出整数范围。" : nil
        idleTimeoutError = timeout == nil ? "请输入大于 0 的整数秒数。" : nil
        didSave = false
        guard let output, let timeout else { return false }
        do {
            try preferences.save(TranslationOptions(outputLimit: output, idleTimeoutSeconds: timeout,
                                                    thinkingEnabled: thinkingEnabled))
            outputLimitText = String(output)
            idleTimeoutText = String(timeout)
            didSave = true
            return true
        } catch {
            outputLimitError = "无法保存翻译参数，请检查输入。"
            return false
        }
    }
}
