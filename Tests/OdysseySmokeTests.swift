import XCTest
import SwiftUI
import UIKit
import Combine
@testable import Odyssey

/// 页面测试挂载真实 UIWindow；仅纯 SwiftUI 品牌组件使用离线 ImageRenderer。

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

    // 10–13. Preserve light/dark page coverage, including native subviews.
    @MainActor
    func testContentViewMountedRenderingLight() async throws {
        try await assertMountedRendering(ContentView(), style: .light, name: "ContentView-Light") {
            self.hasSubview(ThemeAwareTextView.self, in: $0)
        }
    }

    @MainActor
    func testContentViewMountedRenderingDark() async throws {
        try await assertMountedRendering(ContentView(), style: .dark, name: "ContentView-Dark") {
            self.hasSubview(ThemeAwareTextView.self, in: $0)
        }
    }

    @MainActor
    func testSettingsViewMountedRenderingLight() async throws {
        let store = APIConfigurationStore(configurationStorage: MockConfigurationStorage(), keychainService: MockKeychainService())
        try await assertMountedRendering(SettingsView(store: store), style: .light, name: "Settings-Light") {
            self.hasSubview(UICollectionView.self, in: $0)
        }
    }

    @MainActor
    func testSettingsViewMountedRenderingDark() async throws {
        let store = APIConfigurationStore(configurationStorage: MockConfigurationStorage(), keychainService: MockKeychainService())
        try await assertMountedRendering(SettingsView(store: store), style: .dark, name: "Settings-Dark") {
            self.hasSubview(UICollectionView.self, in: $0)
        }
    }

    @MainActor
    private func assertMountedRendering<Content: View>(
        _ view: Content, style: UIUserInterfaceStyle, name: String, ready: (UIView) -> Bool
    ) async throws {
        let fixture = try MountedWindowFixture(rootView: view)
        defer { fixture.close() }
        let size = CGSize(width: 393, height: 852)
        fixture.window.frame = CGRect(origin: .zero, size: size)
        fixture.host.view.frame = fixture.window.bounds
        fixture.window.overrideUserInterfaceStyle = style
        try await fixture.awaitCondition { ready(fixture.host.view) }
        // Allow native Form/NavigationStack to complete the current layout transaction.
        try await Task.sleep(for: .milliseconds(100))
        fixture.host.view.layoutIfNeeded()
        XCTAssertEqual(fixture.host.view.traitCollection.userInterfaceStyle, style)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            XCTAssertTrue(fixture.host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true))
        }
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertEqual(image.size.width, size.width, accuracy: 1.0)
        XCTAssertEqual(image.size.height, size.height, accuracy: 1.0)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func hasSubview<T: UIView>(_ type: T.Type, in view: UIView) -> Bool {
        view is T || view.subviews.contains { hasSubview(type, in: $0) }
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
    // MARK: - 第 3 轮 API 配置与安全存储测试
    // ==========================================

    // 16. 三种格式、显示名称、默认 /v1 与稳定持久化编码
    func testAPIFormatAttributesAndCodable() throws {
        XCTAssertEqual(APIFormat.allCases.count, 3)

        XCTAssertEqual(APIFormat.openAIResponses.rawValue, "openai_responses")
        XCTAssertEqual(APIFormat.openAIChatCompletions.rawValue, "openai_chat_completions")
        XCTAssertEqual(APIFormat.anthropicMessages.rawValue, "anthropic_messages")

        XCTAssertEqual(APIFormat.openAIResponses.displayName, "Responses API")
        XCTAssertEqual(APIFormat.openAIChatCompletions.displayName, "Chat Completions API")
        XCTAssertEqual(APIFormat.anthropicMessages.displayName, "Anthropic API（Messages）")

        XCTAssertEqual(APIFormat.openAIResponses.defaultBaseURL, "https://api.openai.com/v1")
        XCTAssertEqual(APIFormat.openAIChatCompletions.defaultBaseURL, "https://api.openai.com/v1")
        XCTAssertEqual(APIFormat.anthropicMessages.defaultBaseURL, "https://api.anthropic.com/v1")

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
            apiFormat: .openAIChatCompletions,
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
    @MainActor
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
        XCTAssertEqual(store.summaryText, "Responses API · gpt-4o")

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

    // 27–28. Real native fields, with isolated storage and no FocusState bypass.
    @MainActor
    func testAPIConfigurationViewMountedRenderingLight() async throws {
        let store = APIConfigurationStore(configurationStorage: MockConfigurationStorage(), keychainService: MockKeychainService())
        let viewModel = APIConfigurationViewModel(store: store)
        try await assertMountedRendering(
            NavigationStack { APIConfigurationView(viewModel: viewModel) }, style: .light, name: "APIConfiguration-Light"
        ) { self.hasSubview(UITextField.self, in: $0) }
    }

    @MainActor
    func testAPIConfigurationViewMountedRenderingDark() async throws {
        let store = APIConfigurationStore(configurationStorage: MockConfigurationStorage(), keychainService: MockKeychainService())
        let viewModel = APIConfigurationViewModel(store: store)
        try await assertMountedRendering(
            NavigationStack { APIConfigurationView(viewModel: viewModel) }, style: .dark, name: "APIConfiguration-Dark"
        ) { self.hasSubview(UITextField.self, in: $0) }
    }

    // 29. SettingsView 配置完整状态在 393 × 852 模式下真实渲染
    @MainActor
    func testSettingsViewConfiguredMountedRendering() async throws {
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

        try await assertMountedRendering(SettingsView(store: store), style: .light, name: "Settings-Configured") {
            self.hasSubview(UICollectionView.self, in: $0)
        }
    }

    // 30. 原位确认的回调测试（非真实点击）：取消零次删除，确认一次删除。
    @MainActor
    func testClearAPIKeyCallbacksCancelDoesNotDeleteAndConfirmDeletesOnce() throws {
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

        // 未展开时直接调用确认，也不允许删除。
        view.performConfirmClear()
        XCTAssertEqual(keychain.deleteCallCount, 0)

        // 步骤 1：调用展开回调。
        view.handleClearButtonTapped()
        XCTAssertTrue(viewModel.showClearConfirmation, "清除按钮下方应展开确认区域")
        XCTAssertEqual(keychain.deleteCallCount, 0, "展开时绝不得调用删除服务")
        XCTAssertTrue(keychain.hasAPIKey(), "展开时密钥必须保持存在")

        // 步骤 2：调用取消回调。
        view.performCancelClear()
        XCTAssertFalse(viewModel.showClearConfirmation, "点击取消后确认状态应复位为 false")
        XCTAssertEqual(keychain.deleteCallCount, 0, "取消后删除服务调用次数必须保持为 0")
        XCTAssertTrue(keychain.hasAPIKey(), "取消后 Keychain 中的密钥必须完好保留")
        XCTAssertEqual(try keychain.readAPIKey(), initialKey, "读取的密钥文本必须与初始密钥完全一致")
        XCTAssertTrue(viewModel.hasSavedAPIKey, "ViewModel 保存标记依然为 true")
        XCTAssertEqual(store.loadConfiguration(), initialConfig, "非敏感配置必须完整保留未被修改")
        let reopenedViewModel = APIConfigurationViewModel(store: store)
        XCTAssertTrue(reopenedViewModel.hasSavedAPIKey)
        XCTAssertFalse(reopenedViewModel.showClearConfirmation)

        // 步骤 3：用户再次点击“清除已保存的 API Key”
        view.handleClearButtonTapped()
        XCTAssertTrue(viewModel.showClearConfirmation)
        XCTAssertEqual(keychain.deleteCallCount, 0)

        // 步骤 4：调用“确认清除”回调。
        view.performConfirmClear()
        XCTAssertFalse(viewModel.showClearConfirmation, "确认清除后收起确认区域")
        XCTAssertEqual(keychain.deleteCallCount, 1, "确认清除后删除服务必须且仅能调用 1 次")
        XCTAssertFalse(keychain.hasAPIKey(), "确认清除后 Keychain 中的密钥应被彻底删除")
        XCTAssertFalse(viewModel.hasSavedAPIKey, "ViewModel 的 hasSavedAPIKey 应更新为 false")
        XCTAssertEqual(store.loadConfiguration(), initialConfig, "清除密钥操作绝不得篡改或重置非敏感配置")
        view.performConfirmClear()
        XCTAssertEqual(keychain.deleteCallCount, 1, "重复确认不得重复删除")
    }

    // 31. Keychain 替换逻辑：更新失败时必须保留原密钥
    @MainActor
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

    // 33. 验证界面订阅的更新通知；不冒充真实导航返回的 UI 测试。
    @MainActor
    func testSettingsSummaryPublishesOnSaveAndClear() throws {
        let storage = MockConfigurationStorage()
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        let settingsView = SettingsView(store: store)
        var notifications = 0
        let subscription = store.objectWillChange.sink { notifications += 1 }
        defer { subscription.cancel() }

        // 初始未配置状态
        XCTAssertEqual(settingsView.configurationSummary, "未配置", "初始未配置状态摘要应为'未配置'")

        // 模拟在 APIConfigurationView 中保存了新配置与密钥并返回
        let config = APIConfiguration(
            apiFormat: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelID: "gpt-4o"
        )
        try store.save(configuration: config, newAPIKey: "sk-saved-key-888")

        // 保存返回后，SettingsView 的摘要必须即时反映最新的格式与模型
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(settingsView.configurationSummary, "Responses API · gpt-4o")
        try store.clearAPIKey()
        XCTAssertEqual(notifications, 2)
        XCTAssertEqual(settingsView.configurationSummary, "未配置")
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
        let fakeKey = "odyssey-fixture-not-a-real-credential"
        let keychain = MockKeychainService()
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        try store.save(configuration: testConfig, newAPIKey: fakeKey)

        let reloadedConfig = try XCTUnwrap(storage.loadConfiguration())
        XCTAssertEqual(reloadedConfig.apiFormat, .openAIResponses)
        XCTAssertEqual(reloadedConfig.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(reloadedConfig.modelID, "gpt-4o")

        // 验证持久化底层存储中绝对不含 API Key 或任何密钥字段
        let data = try XCTUnwrap(isolatedDefaults.data(forKey: UserDefaultsConfigurationStorage.defaultStorageKey))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["apiFormat", "baseURL", "modelID"]))
        XCTAssertNil(data.range(of: Data(fakeKey.utf8)))
        let domain = try XCTUnwrap(isolatedDefaults.persistentDomain(forName: suiteName))
        XCTAssertEqual(Set(domain.keys), Set([UserDefaultsConfigurationStorage.defaultStorageKey]))
        XCTAssertEqual(try keychain.readAPIKey(), fakeKey)

        // 清理并验证
        storage.clearConfiguration()
        XCTAssertNil(storage.loadConfiguration())
        isolatedDefaults.removePersistentDomain(forName: suiteName)
    }
}
