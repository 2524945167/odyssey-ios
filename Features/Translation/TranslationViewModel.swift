import Foundation
import SwiftUI

@Observable
@MainActor
public final class TranslationViewModel {
    public var sourceText: String = ""
    public var translatedText: String = ""
    public var sourceLanguage: AppLanguage = .chinese
    public var targetLanguage: AppLanguage = .english
    public var isTranslating: Bool = false

    private let clipboard: any ClipboardWriting

    public var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating
    }

    public init(
        sourceText: String = "",
        translatedText: String = "",
        sourceLanguage: AppLanguage = .chinese,
        targetLanguage: AppLanguage = .english,
        clipboard: any ClipboardWriting = SystemClipboardWriter()
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.clipboard = clipboard
    }

    public func clearSource() {
        sourceText = ""
        translatedText = ""
    }

    public func swapLanguages() {
        let previousSource = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = previousSource

        if !translatedText.isEmpty {
            let previousSourceText = sourceText
            sourceText = translatedText
            translatedText = previousSourceText
        }
    }

    public func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        clipboard.setString(translatedText)
    }

    // MARK: - Mock Translation (待第 7 轮由真实 TranslationService 替换)
    /// 本地模拟异步翻译方法，供第 2 轮 UI 交互验证使用。
    /// 严格遵循 async 规范，不调用任何网络或第三方 API，通过 defer 保证状态恢复。
    public func performMockTranslation() async {
        guard canTranslate else { return }
        isTranslating = true
        defer {
            isTranslating = false
        }

        // 模拟 200ms 本地加载等待
        try? await Task.sleep(nanoseconds: 200_000_000)

        if targetLanguage == .english {
            translatedText = "This is a mock translation result for Odyssey Round 2."
        } else {
            translatedText = "这是 Odyssey 第 2 轮的模拟翻译结果。"
        }
    }
}
