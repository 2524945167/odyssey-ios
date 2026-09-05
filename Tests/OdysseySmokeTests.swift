import XCTest
import SwiftUI
@testable import Odyssey

/// 自动化测试离线渲染容器：为 ImageRenderer 隔离无活动 UIWindow 环境下的 FocusState 焦点子系统，
/// 消除离线渲染时的系统虚假警告 "Accessing FocusState's value outside of the body of a View"。
private struct TestRenderContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.enablesFocus, false)
    }
}

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

        XCTAssertTrue(viewModel.sourceText.isEmpty, "调用 clearSource 后原文应被清空")
        XCTAssertTrue(viewModel.translatedText.isEmpty, "调用 clearSource 后译文应被同时清空")
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

    // 9. performMockTranslation 异步可等待性测试
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
        let view = TestRenderContainer {
            ContentView()
        }
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
        let view = TestRenderContainer {
            ContentView()
        }
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
        let view = TestRenderContainer {
            SettingsView()
        }
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
        let view = TestRenderContainer {
            SettingsView()
        }
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
        let view = TestRenderContainer {
            OdysseyBrandTitle()
        }
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
        let view = TestRenderContainer {
            OdysseyBrandTitle()
        }
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
    // MARK: - 第 3 轮 API 配置与安全存储测试
    // ==========================================

    // 16. APIFormat 枚举属性、4 个选项、默认 /v1 与稳定持久化编码
    func testAPIFormatAttributesAndCodable() throws {
        XCTAssertEqual(APIFormat.allCases.count, 4, "APIFormat 应包含 4 种类型")

        XCTAssertEqual(APIFormat.openAIResponses.rawValue, "openai_responses")
        XCTAssertEqual(APIFormat.openAIChatCompletions.rawValue, "openai_chat_completions")
        XCTAssertEqual(APIFormat.anthropicMessages.rawValue, "anthropic_messages")
        XCTAssertEqual(APIFormat.openAICompatible.rawValue, "openai_compatible")

        XCTAssertEqual(APIFormat.openAIResponses.displayName, "OpenAI Responses")
        XCTAssertEqual(APIFormat.openAIChatCompletions.displayName, "OpenAI Chat Completions")
        XCTAssertEqual(APIFormat.anthropicMessages.displayName, "Anthropic Messages")
        XCTAssertEqual(APIFormat.openAICompatible.displayName, "OpenAI Compatible")

        XCTAssertEqual(APIFormat.openAIResponses.defaultBaseURL, "https://api.openai.com/v1")
        XCTAssertEqual(APIFormat.openAIChatCompletions.defaultBaseURL, "https://api.openai.com/v1")
        XCTAssertEqual(APIFormat.anthropicMessages.defaultBaseURL, "https://api.anthropic.com/v1")
        XCTAssertNil(APIFormat.openAICompatible.defaultBaseURL)

        // Codable 往返测试
        for format in APIFormat.allCases {
            let data = try JSONEncoder().encode(format)
            let decoded = try JSONDecoder().decode(APIFormat.self, from: data)
            XCTAssertEqual(decoded, format, "APIFormat \(format) Codable 编解码应保持一致")
        }
    }

    // 17. APIConfiguration 模型 Codable 且不含 API Key，默认 modelID 为空
    func testAPIConfigurationCodable() throws {
        let config = APIConfiguration(
            apiFormat: .anthropicMessages,
            baseURL: "https://api.anthropic.com/v1",
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

        // 验证系统默认配置的默认值规范
        XCTAssertEqual(APIConfiguration.default.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(APIConfiguration.default.modelID, "", "默认 Model ID 必须为空")
    }

    // 18. APIConfigurationValidator URL 校验规则
    func testAPIConfigurationValidatorBaseURL() {
        // 合法 HTTPS 端点
        XCTAssertNoThrow(try APIConfigurationValidator.validateBaseURL("https://api.openai.com/v1"))
        XCTAssertNoThrow(try APIConfigurationValidator.validateBaseURL("https://custom.domain.com/v1/api"))
        XCTAssertNoThrow(try APIConfigurationValidator.validateBaseURL("  https://api.anthropic.com/v1  "))

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
        XCTAssertThrowsError(try APIConfigurationValidator.validateBaseURL("https://api.openai.com#section")) { error in
            XCTAssertEqual(error as? APIValidationError, .containsQueryOrFragment)
        }
    }

    // 19. APIConfigurationValidator Model ID 校验规则
    func testAPIConfigurationValidatorModelID() {
        XCTAssertNoThrow(try APIConfigurationValidator.validateModelID("gpt-4o"))
        XCTAssertNoThrow(try APIConfigurationValidator.validateModelID("claude-3-5-sonnet-20241022"))
        XCTAssertNoThrow(try APIConfigurationValidator.validateModelID("  deepseek-chat  "))

        XCTAssertThrowsError(try APIConfigurationValidator.validateModelID("")) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyModelID)
        }
        XCTAssertThrowsError(try APIConfigurationValidator.validateModelID("   \t\n")) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyModelID)
        }
    }

    // 20. APIConfigurationValidator API Key 校验规则
    func testAPIConfigurationValidatorAPIKey() {
        // 首次配置（Keychain 无 Key）
        XCTAssertNoThrow(try APIConfigurationValidator.validateAPIKey(inputKey: "sk-proj-test12345", hasSavedKey: false))
        XCTAssertThrowsError(try APIConfigurationValidator.validateAPIKey(inputKey: "", hasSavedKey: false)) { error in
            XCTAssertEqual(error as? APIValidationError, .missingAPIKey)
        }
        XCTAssertThrowsError(try APIConfigurationValidator.validateAPIKey(inputKey: "   ", hasSavedKey: false)) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyAPIKey)
        }

        // 二次配置（Keychain 已有 Key）
        XCTAssertNoThrow(try APIConfigurationValidator.validateAPIKey(inputKey: "", hasSavedKey: true), "已有 Key 时允许为空")
        XCTAssertNoThrow(try APIConfigurationValidator.validateAPIKey(inputKey: "sk-new-key", hasSavedKey: true))
        XCTAssertThrowsError(try APIConfigurationValidator.validateAPIKey(inputKey: "   ", hasSavedKey: true)) { error in
            XCTAssertEqual(error as? APIValidationError, .emptyAPIKey)
        }
    }

    // 21. SystemKeychainService 默认服务名与账号名
    func testSystemKeychainServiceDefaults() {
        let service = SystemKeychainService()
        XCTAssertEqual(service.service, "com.kupetis.odyssey.apikey")
        XCTAssertEqual(service.account, "odyssey_active_api_key")
    }

    // 22. MockConfigurationStorage 内存存储
    func testMockConfigurationStorage() throws {
        let storage = MockConfigurationStorage()
        XCTAssertNil(storage.loadConfiguration())

        let config = APIConfiguration(
            apiFormat: .openAICompatible,
            baseURL: "https://my-llm.com/v1",
            modelID: "deepseek-chat"
        )
        try storage.saveConfiguration(config)

        let loaded = storage.loadConfiguration()
        XCTAssertEqual(loaded, config)

        storage.clearConfiguration()
        XCTAssertNil(storage.loadConfiguration())
    }

    // 23. APIConfigurationStore 协调与状态摘要
    func testAPIConfigurationStoreLifecycle() throws {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)

        // 初始未配置
        XCTAssertFalse(store.isConfigured)
        XCTAssertFalse(store.hasSavedAPIKey)
        XCTAssertEqual(store.summaryText, "未配置")

        // 保存配置与 Key
        let config = APIConfiguration(
            apiFormat: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelID: "gpt-4o"
        )
        try store.save(configuration: config, newAPIKey: "sk-test-secret-key-1234")

        XCTAssertTrue(store.isConfigured)
        XCTAssertTrue(store.hasSavedAPIKey)
        XCTAssertEqual(store.summaryText, "OpenAI Responses · gpt-4o")

        // 清除 API Key
        try store.clearAPIKey()
        XCTAssertFalse(store.hasSavedAPIKey)
        XCTAssertFalse(store.isConfigured)
        XCTAssertEqual(store.summaryText, "未配置")

        // 恢复 Key 后清除全部
        try keychain.saveAPIKey("sk-test-secret-key-1234")
        XCTAssertTrue(store.isConfigured)
        try store.clearAll()
        XCTAssertFalse(store.isConfigured)
        XCTAssertFalse(store.hasSavedAPIKey)
        XCTAssertNil(storage.loadConfiguration())
    }

    // 24. APIConfigurationViewModel 自动填充、明确跟踪手动编辑与恢复默认
    @MainActor
    func testAPIConfigurationViewModelAutoFillAndReset() {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        // 默认状态
        XCTAssertEqual(viewModel.apiFormat, .openAIResponses)
        XCTAssertEqual(viewModel.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(viewModel.modelID, "", "默认 Model ID 必须为空")
        XCTAssertFalse(viewModel.isBaseURLCustomized, "初始状态未手动定制 Base URL")

        // 切换到 Anthropic：自动填充 Anthropic 默认 Base URL
        viewModel.apiFormat = .anthropicMessages
        XCTAssertEqual(viewModel.baseURL, "https://api.anthropic.com/v1")
        XCTAssertFalse(viewModel.isBaseURLCustomized)

        // 切换到 OpenAI Compatible：无默认地址，自动填充为空
        viewModel.apiFormat = .openAICompatible
        XCTAssertEqual(viewModel.baseURL, "")
        XCTAssertFalse(viewModel.isBaseURLCustomized)

        // 切换到 Chat Completions：自动填充 OpenAI 默认 Base URL
        viewModel.apiFormat = .openAIChatCompletions
        XCTAssertEqual(viewModel.baseURL, "https://api.openai.com/v1")
        XCTAssertFalse(viewModel.isBaseURLCustomized)

        // 用户手动输入自定义端点
        viewModel.baseURL = "https://custom-proxy.internal.net"
        XCTAssertTrue(viewModel.isBaseURLCustomized, "手动输入后标记为已定制")

        // 切换到 OpenAI Responses：已定制 Base URL 必须保留，不得被格式默认值覆盖
        viewModel.apiFormat = .openAIResponses
        XCTAssertEqual(viewModel.baseURL, "https://custom-proxy.internal.net")
        XCTAssertTrue(viewModel.isBaseURLCustomized)

        // 切换到 Anthropic：依然保留自定义端点
        viewModel.apiFormat = .anthropicMessages
        XCTAssertEqual(viewModel.baseURL, "https://custom-proxy.internal.net")

        // 触发恢复默认
        viewModel.resetBaseURLToDefault()
        XCTAssertEqual(viewModel.baseURL, "https://api.anthropic.com/v1")
        XCTAssertFalse(viewModel.isBaseURLCustomized, "恢复默认后复位定制标记")

        // 再次切换到 OpenAI Responses：自动更新为新格式默认值
        viewModel.apiFormat = .openAIResponses
        XCTAssertEqual(viewModel.baseURL, "https://api.openai.com/v1")
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
        viewModel.modelID = "gpt-4o"
        viewModel.apiKeyInput = "sk-valid-key"
        XCTAssertFalse(viewModel.save())
        XCTAssertEqual(viewModel.baseURLValidationError, APIValidationError.invalidScheme.localizedDescription)

        // 修正为合法配置并保存
        viewModel.baseURL = "https://api.openai.com/v1"
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

    // 26. APIConfigurationViewModel 清除 API Key
    @MainActor
    func testAPIConfigurationViewModelClearAPIKey() throws {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService(initialStorage: [
            "\(SystemKeychainService.defaultService).\(SystemKeychainService.defaultAccount)": "sk-exist-key"
        ])
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        XCTAssertTrue(viewModel.hasSavedAPIKey)

        viewModel.clearAPIKey()

        XCTAssertFalse(viewModel.hasSavedAPIKey)
        XCTAssertFalse(keychain.hasAPIKey())
        XCTAssertEqual(viewModel.saveSuccessMessage, "已安全清除 API Key")
    }

    // 27. APIConfigurationView 在 393 × 852 浅色模式下可通过 ImageRenderer 渲染
    @MainActor
    func testAPIConfigurationViewImageRendererLight() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        let view = TestRenderContainer {
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

    // 28. APIConfigurationView 在 393 × 852 深色模式下可通过 ImageRenderer 渲染
    @MainActor
    func testAPIConfigurationViewImageRendererDark() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        let view = TestRenderContainer {
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

    // 29. SettingsView 配置完整状态在 393 × 852 模式下可通过 ImageRenderer 渲染
    @MainActor
    func testSettingsViewConfiguredImageRenderer() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let config = APIConfiguration(
            apiFormat: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelID: "gpt-4o"
        )
        let storage = MockConfigurationStorage(initialConfiguration: config)
        let keychain = MockKeychainService(initialStorage: [
            "\(SystemKeychainService.defaultService).\(SystemKeychainService.defaultAccount)": "sk-test-key-5678"
        ])
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)

        let view = TestRenderContainer {
            SettingsView(store: store)
        }
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

    // 30. 清除 API Key 按钮交互验证：取消调用 0 次，确认调用 1 次
    @MainActor
    func testClearAPIKeyCancelDoesNotDeleteAndConfirmDeletesOnce() throws {
        let initialConfig = APIConfiguration(
            apiFormat: .openAIChatCompletions,
            baseURL: "https://api.openai.com/v1",
            modelID: "gpt-4o"
        )
        let initialKey = "sk-live-secret-key-12345"
        let storage = MockConfigurationStorage(initialConfiguration: initialConfig)
        let keychain = MockKeychainService(initialStorage: [
            "\(SystemKeychainService.defaultService).\(SystemKeychainService.defaultAccount)": initialKey
        ])
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)
        let view = APIConfigurationView(viewModel: viewModel)

        XCTAssertEqual(keychain.deleteCallCount, 0, "初始删除服务调用次数必须为 0")
        XCTAssertTrue(keychain.hasAPIKey(), "初始 Keychain 中必须存在密钥")
        XCTAssertTrue(viewModel.hasSavedAPIKey)

        // 步骤 1：用户点击页面上的“清除已保存的 API Key”按钮
        view.handleClearButtonTapped()
        XCTAssertTrue(viewModel.showClearConfirmation, "点击清除按钮后应将确认状态设为 true 呼出系统对话框")
        XCTAssertEqual(keychain.deleteCallCount, 0, "呼出确认对话框时绝不得调用删除服务")
        XCTAssertTrue(keychain.hasAPIKey(), "呼出确认对话框时密钥必须保持存在")

        // 步骤 2：用户在系统对话框中点击“取消”（或点击遮罩外部关闭）
        view.performCancelClear()
        XCTAssertFalse(viewModel.showClearConfirmation, "点击取消后确认状态应复位为 false")
        XCTAssertEqual(keychain.deleteCallCount, 0, "取消后删除服务调用次数必须保持为 0")
        XCTAssertTrue(keychain.hasAPIKey(), "取消后 Keychain 中的密钥必须完好保留")
        XCTAssertEqual(try keychain.readAPIKey(), initialKey, "读取的密钥文本必须与初始密钥完全一致")
        XCTAssertTrue(viewModel.hasSavedAPIKey, "ViewModel 保存标记依然为 true")
        XCTAssertEqual(store.loadConfiguration(), initialConfig, "非敏感配置必须完整保留未被修改")

        // 步骤 3：用户再次点击“清除已保存的 API Key”
        view.handleClearButtonTapped()
        XCTAssertTrue(viewModel.showClearConfirmation)
        XCTAssertEqual(keychain.deleteCallCount, 0)

        // 步骤 4：用户在系统对话框中明确点击“清除 API Key”确认
        view.performConfirmClear()
        XCTAssertFalse(viewModel.showClearConfirmation, "确认清除后对话框状态复位为 false")
        XCTAssertEqual(keychain.deleteCallCount, 1, "确认清除后删除服务必须且仅能调用 1 次")
        XCTAssertFalse(keychain.hasAPIKey(), "确认清除后 Keychain 中的密钥应被彻底删除")
        XCTAssertFalse(viewModel.hasSavedAPIKey, "ViewModel 的 hasSavedAPIKey 应更新为 false")
        XCTAssertEqual(store.loadConfiguration(), initialConfig, "清除密钥操作绝不得篡改或重置非敏感配置")
    }

    // 31. Keychain 替换逻辑：更新失败时必须保留原密钥
    func testKeychainUpdateFailurePreservesOriginalKey() throws {
        let originalKey = "sk-original-active-key-1122"
        let newKey = "sk-failed-replacement-key-3344"
        let keychain = MockKeychainService(initialStorage: [
            "\(SystemKeychainService.defaultService).\(SystemKeychainService.defaultAccount)": originalKey
        ])
        let storage = MockConfigurationStorage()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)

        XCTAssertTrue(keychain.hasAPIKey())
        XCTAssertEqual(try keychain.readAPIKey(), originalKey)

        // 模拟更新操作抛出系统异常
        keychain.simulateUpdateError = KeychainError.unexpectedStatus(errSecInternalComponent)

        let config = APIConfiguration(
            apiFormat: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelID: "gpt-4o"
        )

        // 尝试保存新密钥，预期抛出异常
        XCTAssertThrowsError(try store.save(configuration: config, newAPIKey: newKey))

        // 验证调用统计与原密钥保持不变
        XCTAssertEqual(keychain.updateCallCount, 1, "应尝试调用更新 1 次")
        XCTAssertEqual(keychain.deleteCallCount, 0, "禁止执行先删后加，删除调用次数必须为 0")
        XCTAssertEqual(try keychain.readAPIKey(), originalKey, "更新失败时原密钥必须完好无损保留")
    }

    // 32. 用户编辑字段后立即清除对应字段的旧验证错误，不必等待再次点击保存
    @MainActor
    func testInlineValidationErrorsClearedImmediatelyOnEditing() {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let viewModel = APIConfigurationViewModel(store: store)

        // 制造全字段校验错误
        viewModel.baseURL = "invalid-url-scheme"
        viewModel.modelID = ""
        viewModel.apiKeyInput = ""

        let firstError = viewModel.validate()
        XCTAssertEqual(firstError, .baseURL)
        XCTAssertNotNil(viewModel.baseURLValidationError)
        XCTAssertNotNil(viewModel.modelIDValidationError)
        XCTAssertNotNil(viewModel.apiKeyValidationError)

        // 1. 用户编辑 Base URL
        viewModel.baseURL = "https://api.openai.com/v1"
        XCTAssertNil(viewModel.baseURLValidationError, "编辑 Base URL 后错误提示应立即清除")
        XCTAssertNotNil(viewModel.modelIDValidationError, "其他字段错误应保持不受影响")
        XCTAssertNotNil(viewModel.apiKeyValidationError)

        // 2. 用户编辑 Model ID
        viewModel.modelID = "gpt-4o"
        XCTAssertNil(viewModel.modelIDValidationError, "编辑 Model ID 后错误提示应立即清除")
        XCTAssertNotNil(viewModel.apiKeyValidationError)

        // 3. 用户编辑 API Key
        viewModel.apiKeyInput = "sk-some-new-key"
        XCTAssertNil(viewModel.apiKeyValidationError, "编辑 API Key 后错误提示应立即清除")
    }

    // 33. 设置首页摘要在保存返回后通过 refreshSummary 立即刷新
    @MainActor
    func testSettingsViewSummaryRefreshesOnSaveReturn() throws {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)

        let viewModel = SettingsViewModel(store: store)
        XCTAssertEqual(viewModel.configurationSummary, "未配置", "初始未配置状态摘要应为'未配置'")

        let settingsView = SettingsView(viewModel: viewModel)
        XCTAssertEqual(settingsView.viewModel.configurationSummary, "未配置")

        // 模拟子页面保存了新配置与密钥
        let config = APIConfiguration(
            apiFormat: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelID: "gpt-4o"
        )
        try store.save(configuration: config, newAPIKey: "sk-saved-key-888")

        // 验证调用刷新后状态立即同步
        settingsView.refreshSummary()
        XCTAssertEqual(viewModel.configurationSummary, "OpenAI Responses · gpt-4o", "保存返回并刷新后摘要必须立即更新")
        XCTAssertEqual(settingsView.viewModel.configurationSummary, "OpenAI Responses · gpt-4o")
    }

    // 34. 隔离的 UserDefaults suite 测试：配置可保存加载、无敏感密钥残留、测试后清理隔离域
    @MainActor
    func testIsolatedUserDefaultsConfigurationStorage() throws {
        let suiteName = "com.kupetis.odyssey.tests.isolated_\(UUID().uuidString)"
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }

        let isolatedDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let storage = UserDefaultsConfigurationStorage(userDefaults: isolatedDefaults)
        XCTAssertNil(storage.loadConfiguration(), "初始状态应无已保存配置")

        let testConfig = APIConfiguration(
            apiFormat: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelID: "gpt-4o"
        )
        try storage.saveConfiguration(testConfig)

        let reloadedConfig = try XCTUnwrap(storage.loadConfiguration())
        XCTAssertEqual(reloadedConfig.apiFormat, .openAIResponses)
        XCTAssertEqual(reloadedConfig.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(reloadedConfig.modelID, "gpt-4o")

        // 验证持久化底层存储中绝对不含 API Key 或任何密钥字段
        let allValues = isolatedDefaults.dictionaryRepresentation()
        let serializedDict = String(describing: allValues)
        XCTAssertFalse(serializedDict.contains("apiKey"), "UserDefaults 中严禁包含 apiKey")
        XCTAssertFalse(serializedDict.contains("api_key"), "UserDefaults 中严禁包含 api_key")
        XCTAssertFalse(serializedDict.contains("sk-"), "UserDefaults 中严禁包含任何密钥明文")

        // 清理并验证
        storage.clearConfiguration()
        XCTAssertNil(storage.loadConfiguration())
        isolatedDefaults.removePersistentDomain(forName: suiteName)
    }
}
