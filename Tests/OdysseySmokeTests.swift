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

    // 14. OdysseyBrandTitle 在浅色模式下可通过 ImageRenderer 成功渲染
    @MainActor
    func testBrandTitleImageRendererLight() throws {
        let view = OdysseyBrandTitle()
            .padding()
            .preferredColorScheme(.light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "浅色模式下 OdysseyBrandTitle 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0, "品牌组件浅色渲染宽度必须大于 0")
        XCTAssertGreaterThan(image.size.height, 0, "品牌组件浅色渲染高度必须大于 0")
    }

    // 15. OdysseyBrandTitle 在深色模式下可通过 ImageRenderer 成功渲染
    @MainActor
    func testBrandTitleImageRendererDark() throws {
        let view = OdysseyBrandTitle()
            .padding()
            .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "深色模式下 OdysseyBrandTitle 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0, "品牌组件深色渲染宽度必须大于 0")
        XCTAssertGreaterThan(image.size.height, 0, "品牌组件深色渲染高度必须大于 0")
    }

    // ==========================================
    // MARK: - 第 3 轮 API 配置与安全存储新增测试
    // ==========================================

    // 16. APIFormat 枚举属性与持久化编码
    func testAPIFormatAttributesAndCodable() throws {
        XCTAssertEqual(APIFormat.allCases.count, 4, "APIFormat 应包含 4 种类型")

        XCTAssertEqual(APIFormat.openAIResponses.rawValue, "openai_responses")
        XCTAssertEqual(APIFormat.openAIChatCompletions.rawValue, "openai_chat_completions")
        XCTAssertEqual(APIFormat.anthropicMessages.rawValue, "anthropic_messages")
        XCTAssertEqual(APIFormat.openAICompatible.rawValue, "openai_compatible")

        XCTAssertEqual(APIFormat.openAIResponses.defaultBaseURL, "https://api.openai.com")
        XCTAssertEqual(APIFormat.openAIChatCompletions.defaultBaseURL, "https://api.openai.com")
        XCTAssertEqual(APIFormat.anthropicMessages.defaultBaseURL, "https://api.anthropic.com")
        XCTAssertNil(APIFormat.openAICompatible.defaultBaseURL)

        // Codable 往返测试
        for format in APIFormat.allCases {
            let data = try JSONEncoder().encode(format)
            let decoded = try JSONDecoder().decode(APIFormat.self, from: data)
            XCTAssertEqual(decoded, format, "APIFormat \(format) Codable 编解码应保持一致")
        }
    }

    // 17. APIConfiguration 模型 Codable 且不含 API Key
    func testAPIConfigurationCodable() throws {
        let config = APIConfiguration(
            apiFormat: .anthropicMessages,
            baseURL: "https://api.anthropic.com",
            modelID: "claude-3-5-sonnet-20241022"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let jsonString = try XCTUnwrap(String(data: data, encoding: .utf8))

        // 验证 JSON 中决不包含 apiKey 字段
        XCTAssertFalse(jsonString.contains("apiKey"), "APIConfiguration JSON 不得包含 apiKey")
        XCTAssertFalse(jsonString.contains("api_key"), "APIConfiguration JSON 不得包含 api_key")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(APIConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // 18. APIConfigurationValidator URL 校验规则
    func testAPIConfigurationValidatorBaseURL() {
        // 合法 HTTPS 端点
        XCTAssertNoThrow(try APIConfigurationValidator.validateBaseURL("https://api.openai.com"))
        XCTAssertNoThrow(try APIConfigurationValidator.validateBaseURL("https://custom.domain.com/v1/api"))
        XCTAssertNoThrow(try APIConfigurationValidator.validateBaseURL("  https://api.anthropic.com  "))

        // 空地址
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("")) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyBaseURL)
        }
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("   \n\t")) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyBaseURL)
        }

        // 非 HTTPS 协议（如 HTTP）
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("http://api.openai.com")) { error in
            XCTAssertEqual(error as? APIValidationError, .invalidScheme)
        }
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("ftp://api.openai.com")) { error in
            XCTAssertEqual(error as? APIValidationError, .invalidScheme)
        }

        // 缺少 Host
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("https://")) { error in
            XCTAssertEqual(error as? APIValidationError, .missingHost)
        }

        // 嵌入凭据
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("https://user:pass@api.openai.com")) { error in
            XCTAssertEqual(error as? APIValidationError, .containsCredentials)
        }

        // 包含 Query 或 Fragment
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("https://api.openai.com?key=123")) { error in
            XCTAssertEqual(error as? APIValidationError, .containsQueryOrFragment)
        }
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("https://api.openai.com#hash")) { error in
            XCTAssertEqual(error as? APIValidationError, .containsQueryOrFragment)
        }
    }

    // 19. APIConfigurationValidator Model ID 校验规则
    func testAPIConfigurationValidatorModelID() {
        XCTAssertNoThrow(try APIConfigurationValidator.validateModelID("gpt-4o"))
        XCTAssertNoThrow(try APIConfigurationValidator.validateModelID("  claude-3-5-sonnet  "))

        XCTAssertThrowsError(try APIConfigurationValidator.validateModelID("")) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyModelID)
        }
        XCTAssertThrowsError(try APIConfigurationValidator.validateModelID("   \n")) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyModelID)
        }
    }

    // 20. APIConfigurationValidator API Key 校验规则
    func testAPIConfigurationValidatorAPIKey() {
        // 新增配置（hasSavedKey: false）
        XCTAssertNoThrow(try APIConfigurationValidator.validateAPIKey(inputKey: "sk-proj-test12345", hasSavedKey: false))
        XCTAssertThrowsError(try APIConfigurationValidator.validateAPIKey(inputKey: "", hasSavedKey: false)) { error in
            XCTAssertEqual(error as? APIValidationError, .missingAPIKey)
        }
        XCTAssertThrowsError(try APIConfigurationValidator.validateAPIKey(inputKey: "   ", hasSavedKey: false)) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyAPIKey)
        }

        // 编辑已有配置（hasSavedKey: true，允许空输入代表保留旧密钥）
        XCTAssertNoThrow(try APIConfigurationValidator.validateAPIKey(inputKey: "", hasSavedKey: true))
        XCTAssertNoThrow(try APIConfigurationValidator.validateAPIKey(inputKey: "sk-new-key", hasSavedKey: true))
        XCTAssertThrowsError(try APIConfigurationValidator.validateAPIKey(inputKey: "   \t", hasSavedKey: true)) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyAPIKey)
        }
    }

    // 21. MockKeychainService 独立操作测试
    func testMockKeychainService() throws {
        let keychain = MockKeychainService()
        XCTAssertFalse(keychain.hasAPIKey())

        try keychain.saveAPIKey("mock-secret-key-123")
        XCTAssertTrue(keychain.hasAPIKey())
        XCTAssertEqual(try keychain.readAPIKey(), "mock-secret-key-123")

        try keychain.deleteAPIKey()
        XCTAssertFalse(keychain.hasAPIKey())

        XCTAssertThrowsError(try keychain.readAPIKey()) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }

    // 22. MockConfigurationStorage 独立操作测试
    func testMockConfigurationStorage() throws {
        let storage = MockConfigurationStorage()
        XCTAssertNil(storage.loadConfiguration())

        let config = APIConfiguration(
            apiFormat: .openAICompatible,
            baseURL: "https://my-llm.com/v1",
            modelID: "deepseek-chat"
        )
        try storage.saveConfiguration(config)
        XCTAssertEqual(storage.loadConfiguration(), config)

        storage.clearConfiguration()
        XCTAssertNil(storage.loadConfiguration())
    }

    // 23. APIConfigurationStore 协调配置与钥匙串
    func testAPIConfigurationStoreCoordination() throws {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)

        XCTAssertFalse(store.isConfigured)
        XCTAssertEqual(store.summaryText, "未配置")

        let config = APIConfiguration(
            apiFormat: .openAIResponses,
            baseURL: "https://api.openai.com",
            modelID: "gpt-4o"
        )
        try store.save(configuration: config, newAPIKey: "sk-mock-key")

        XCTAssertTrue(store.isConfigured)
        XCTAssertTrue(store.hasSavedAPIKey)
        XCTAssertEqual(store.summaryText, "OpenAI Responses · gpt-4o")

        // 清除 API Key
        try store.clearAPIKey()
        XCTAssertFalse(store.hasSavedAPIKey)
        XCTAssertFalse(store.isConfigured, "缺少有效 API Key 时 isConfigured 应为 false")
        XCTAssertEqual(store.summaryText, "未配置")
    }

    // 24. APIConfigurationViewModel 联动自动填充与恢复默认
    @MainActor
    func testAPIConfigurationViewModelAutoFillAndReset() {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        // 默认状态
        XCTAssertEqual(viewModel.apiFormat, .openAIResponses)
        XCTAssertEqual(viewModel.baseURL, "https://api.openai.com")
        XCTAssertEqual(viewModel.modelID, "gpt-4o")

        // 切换到 Anthropic：自动填充 Anthropic 默认 Base URL
        viewModel.apiFormat = .anthropicMessages
        XCTAssertEqual(viewModel.baseURL, "https://api.anthropic.com")

        // 切换到 OpenAI Compatible：官方无默认 URL，自动清空
        viewModel.apiFormat = .openAICompatible
        XCTAssertEqual(viewModel.baseURL, "")

        // 用户输入自定义端点
        viewModel.baseURL = "https://custom-proxy.internal.net"
        // 再次切换到 OpenAI Responses：由于用户自定义过且不等于 Compatible 默认值，保留用户端点
        viewModel.apiFormat = .openAIResponses
        XCTAssertEqual(viewModel.baseURL, "https://custom-proxy.internal.net")

        // 触发恢复默认
        viewModel.resetBaseURLToDefault()
        XCTAssertEqual(viewModel.baseURL, "https://api.openai.com")

        viewModel.modelID = "custom-model"
        viewModel.resetModelIDToDefault()
        XCTAssertEqual(viewModel.modelID, "gpt-4o")
    }

    // 25. APIConfigurationViewModel 保存拦截与成功保存
    @MainActor
    func testAPIConfigurationViewModelSaveLifecycle() {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        // 初始状态：无保存的 Key 且输入为空，保存应被拦截
        let initialSaveResult = viewModel.save()
        XCTAssertFalse(initialSaveResult)
        XCTAssertEqual(viewModel.apiKeyValidationError, APIValidationError.missingAPIKey.localizedDescription)

        // 输入非法 URL
        viewModel.baseURL = "http://insecure.url"
        viewModel.apiKeyInput = "sk-valid-key"
        XCTAssertFalse(viewModel.save())
        XCTAssertEqual(viewModel.baseURLValidationError, APIValidationError.invalidScheme.localizedDescription)

        // 修正为合法配置并保存
        viewModel.baseURL = "https://api.openai.com"
        let success = viewModel.save()
        XCTAssertTrue(success)
        XCTAssertTrue(viewModel.hasSavedAPIKey)
        XCTAssertTrue(viewModel.apiKeyInput.isEmpty, "保存成功后应清空输入框文本")
        XCTAssertEqual(viewModel.saveSuccessMessage, "配置已成功保存")
        XCTAssertNil(viewModel.baseURLValidationError)
        XCTAssertNil(viewModel.apiKeyValidationError)

        // 再次保存（保留已保存密钥，空输入）
        let retainSuccess = viewModel.save()
        XCTAssertTrue(retainSuccess, "已有有效密钥时空输入应能成功保存并保留旧 Key")
    }

    // 26. APIConfigurationView 在 393 × 852 浅色模式下可通过 ImageRenderer 渲染
    @MainActor
    func testAPIConfigurationViewImageRendererLight() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        let view = NavigationStack {
            APIConfigurationView(viewModel: viewModel)
        }
        .frame(width: targetWidth, height: targetHeight)
        .preferredColorScheme(.light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "浅色模式下 APIConfigurationView 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertEqual(image.size.width, targetWidth, accuracy: 1.0)
        XCTAssertEqual(image.size.height, targetHeight, accuracy: 1.0)
    }

    // 27. APIConfigurationView 在 393 × 852 深色模式下可通过 ImageRenderer 渲染
    @MainActor
    func testAPIConfigurationViewImageRendererDark() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        let view = NavigationStack {
            APIConfigurationView(viewModel: viewModel)
        }
        .frame(width: targetWidth, height: targetHeight)
        .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "深色模式下 APIConfigurationView 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertEqual(image.size.width, targetWidth, accuracy: 1.0)
        XCTAssertEqual(image.size.height, targetHeight, accuracy: 1.0)
    }

    // 28. SettingsView 配置完整状态在 393 × 852 模式下可通过 ImageRenderer 渲染
    @MainActor
    func testSettingsViewConfiguredImageRenderer() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let config = APIConfiguration(
            apiFormat: .openAIResponses,
            baseURL: "https://api.openai.com",
            modelID: "gpt-4o"
        )
        let storage = MockConfigurationStorage(initialConfiguration: config)
        let keychain = MockKeychainService(initialStorage: [
            "\(SystemKeychainService.defaultService).\(SystemKeychainService.defaultAccount)": "sk-dummy"
        ])
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)

        let view = SettingsView(store: store)
            .frame(width: targetWidth, height: targetHeight)
            .preferredColorScheme(.light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "配置完整状态下 SettingsView 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertEqual(image.size.width, targetWidth, accuracy: 1.0)
        XCTAssertEqual(image.size.height, targetHeight, accuracy: 1.0)
    }
}
