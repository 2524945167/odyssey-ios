import XCTest
import SwiftUI
@testable import Odyssey

final class OdysseySmokeTests: XCTestCase {

    // 1. AppLanguage 短标签测试
    @MainActor
    func testAppLanguageShortDisplayName() {
        XCTAssertEqual(AppLanguage.chinese.shortDisplayName, "中", "简体中文短标签应为'中'")
        XCTAssertEqual(AppLanguage.english.shortDisplayName, "英", "英语短标签应为'英'")
    }

    // 2. 默认语言为简体中文到英语
    @MainActor
    func testDefaultLanguages() {
        let viewModel = TranslationViewModel()
        XCTAssertEqual(viewModel.sourceLanguage, .chinese, "默认源语言应为简体中文")
        XCTAssertEqual(viewModel.targetLanguage, .english, "默认目标语言应为英语")
        XCTAssertTrue(viewModel.sourceText.isEmpty, "初始原文必须为空")
        XCTAssertTrue(viewModel.translatedText.isEmpty, "初始译文必须为空")
    }

    // 3. 原文为空时 canTranslate 为 false
    @MainActor
    func testCanTranslateWhenEmpty() {
        let viewModel = TranslationViewModel()
        viewModel.sourceText = ""
        XCTAssertFalse(viewModel.canTranslate, "原文为空时 canTranslate 应为 false")
    }

    // 4. canTranslate 必须把空格、换行和制表符视为空内容
    @MainActor
    func testCanTranslateTreatsWhitespaceAndNewlinesAsEmpty() {
        let viewModel = TranslationViewModel()
        let blankInputs = [" ", "   ", "\t", "\n", "\r\n", " \t \n "]
        for input in blankInputs {
            viewModel.sourceText = input
            XCTAssertFalse(viewModel.canTranslate, "仅含空白或换行符时 canTranslate 应为 false: '\(input)'")
        }
    }

    // 5. 输入有效文本后 canTranslate 为 true
    @MainActor
    func testCanTranslateWithValidContent() {
        let viewModel = TranslationViewModel()
        viewModel.sourceText = "你好，世界"
        XCTAssertTrue(viewModel.canTranslate, "输入有效文本后 canTranslate 应为 true")
    }

    // 6. 清除原文同时清除译文
    @MainActor
    func testClearSourceClearsBothSourceAndTranslation() {
        let viewModel = TranslationViewModel(
            sourceText: "待翻译文本",
            translatedText: "Text to be translated"
        )
        XCTAssertFalse(viewModel.sourceText.isEmpty)
        XCTAssertFalse(viewModel.translatedText.isEmpty)

        viewModel.clearSource()

        XCTAssertTrue(viewModel.sourceText.isEmpty, "清除后原文应为空")
        XCTAssertTrue(viewModel.translatedText.isEmpty, "清除原文时译文应同步清空")
    }

    // 7. 交换语言后方向正确
    @MainActor
    func testSwapLanguagesDirection() {
        let viewModel = TranslationViewModel(
            sourceText: "你好",
            translatedText: "Hello",
            sourceLanguage: .chinese,
            targetLanguage: .english
        )

        viewModel.swapLanguages()

        XCTAssertEqual(viewModel.sourceLanguage, .english, "交换后源语言应为英语")
        XCTAssertEqual(viewModel.targetLanguage, .chinese, "交换后目标语言应为简体中文")
        XCTAssertEqual(viewModel.sourceText, "Hello", "交换后原文应承接原译文")
        XCTAssertEqual(viewModel.translatedText, "你好", "交换后译文应承接原原文")
    }

    // 8. 复制功能通过轻量 ClipboardWriting 注入，测试不修改真实系统剪贴板
    @MainActor
    func testCopyTranslationWithInjectedClipboard() {
        let mockClipboard = MockClipboardWriter()
        let viewModel = TranslationViewModel(
            translatedText: "Unit test mock copy string",
            clipboard: mockClipboard
        )

        viewModel.copyTranslation()

        XCTAssertEqual(mockClipboard.storedString, "Unit test mock copy string", "复制应写入注入的 MockClipboardWriter，不污染系统剪贴板")
    }

    // 9. performMockTranslation 是可等待的 async 方法，阻止重复触发，defer 恢复 isTranslating
    @MainActor
    func testPerformMockTranslationAsync() async {
        let viewModel = TranslationViewModel(sourceText: "测试翻译")
        XCTAssertFalse(viewModel.isTranslating)

        await viewModel.performMockTranslation()

        XCTAssertFalse(viewModel.isTranslating, "Mock 翻译完成后 isTranslating 应自动重置为 false")
        XCTAssertFalse(viewModel.translatedText.isEmpty, "Mock 翻译应生成非空译文")
    }

    // 10. ContentView 在 393 × 852 浅色模式下可通过 ImageRenderer 渲染
    @MainActor
    func testContentViewImageRendererLight() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let view = ContentView()
            .frame(width: targetWidth, height: targetHeight)
            .preferredColorScheme(.light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "浅色模式下 ContentView 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0, "渲染宽度必须大于 0")
        XCTAssertGreaterThan(image.size.height, 0, "渲染高度必须大于 0")
        XCTAssertEqual(image.size.width, targetWidth, accuracy: 1.0, "渲染宽度应与 frame 尺寸匹配")
        XCTAssertEqual(image.size.height, targetHeight, accuracy: 1.0, "渲染高度应与 frame 尺寸匹配")
    }

    // 11. ContentView 在 393 × 852 深色模式下可通过 ImageRenderer 渲染
    @MainActor
    func testContentViewImageRendererDark() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let view = ContentView()
            .frame(width: targetWidth, height: targetHeight)
            .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "深色模式下 ContentView 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0, "深色模式渲染宽度必须大于 0")
        XCTAssertGreaterThan(image.size.height, 0, "深色模式渲染高度必须大于 0")
        XCTAssertEqual(image.size.width, targetWidth, accuracy: 1.0, "深色模式渲染宽度应与 frame 尺寸匹配")
        XCTAssertEqual(image.size.height, targetHeight, accuracy: 1.0, "深色模式渲染高度应与 frame 尺寸匹配")
    }

    // 12. SettingsView 在 393 × 852 浅色模式下可通过 ImageRenderer 渲染
    @MainActor
    func testSettingsViewImageRendererLight() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let view = SettingsView()
            .frame(width: targetWidth, height: targetHeight)
            .preferredColorScheme(.light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "浅色模式下 SettingsView 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0, "渲染宽度必须大于 0")
        XCTAssertGreaterThan(image.size.height, 0, "渲染高度必须大于 0")
        XCTAssertEqual(image.size.width, targetWidth, accuracy: 1.0, "渲染宽度应与 frame 尺寸匹配")
        XCTAssertEqual(image.size.height, targetHeight, accuracy: 1.0, "渲染高度应与 frame 尺寸匹配")
    }

    // 13. SettingsView 在 393 × 852 深色模式下可通过 ImageRenderer 渲染
    @MainActor
    func testSettingsViewImageRendererDark() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let view = SettingsView()
            .frame(width: targetWidth, height: targetHeight)
            .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "深色模式下 SettingsView 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0, "深色模式渲染宽度必须大于 0")
        XCTAssertGreaterThan(image.size.height, 0, "深色模式渲染高度必须大于 0")
        XCTAssertEqual(image.size.width, targetWidth, accuracy: 1.0, "深色模式渲染宽度应与 frame 尺寸匹配")
        XCTAssertEqual(image.size.height, targetHeight, accuracy: 1.0, "深色模式渲染高度应与 frame 尺寸匹配")
    }
}
